class TaxonFrameworkRelationshipsController < ApplicationController
  before_filter :find_taxon_framework_relationship, only: [:show, :edit]
  before_filter :authenticate_user!, except: [:index, :show]
  before_filter :curator_required, only: [:new, :create, :edit, :update, :destroy]
  before_filter :taxon_curator_required, only: [:edit, :update, :destroy]
  before_action :set_taxon_framework_relationship, except: [:index, :new, :create]
  
  layout "bootstrap"
  
  def find_taxon_framework_relationship
    begin
      @taxon_framework_relationship = TaxonFrameworkRelationship.find( params[:id] )
    rescue
      render_404
    end
  end
  
  def taxon_curator_required
    set_taxon_framework_relationship
    taxon_framework = @taxon_framework_relationship.taxon_framework
    unless logged_in? && current_user.is_curator? && ( !taxon_framework.taxon_curators.any? || ( taxon_framework.taxon_curators.any? && taxon_framework.taxon_curators.where( user: current_user ).exists? ) )
    flash[:notice] = "only taxon curators for #{taxon_framework.taxon.name} can access that page"
      if session[:return_to] == request.fullpath
        redirect_to root_url
      else
        redirect_back_or_default(root_url)
      end
      return false
    end
  end
  
  def index
    filter_params = params[:filters] || params
    @relationships = filter_params[:relationships]
    @relationships ||= TaxonFrameworkRelationship::RELATIONSHIPS.map{ |r| filter_params[r] == "1" ? r : nil }
    @relationships.delete_if{ |r| r.blank? }
    @taxon_framework = TaxonFramework.find_by_id( filter_params[:taxon_framework_id] ) unless filter_params[:taxon_framework_id].blank?    
    @taxon_frameworks = TaxonFramework.includes( :taxon ).where( "taxon_frameworks.rank_level IS NOT NULL" ).order( "taxa.name" ).limit( 100 )
    @taxon = Taxon.find_by_id( filter_params[:taxon_id].to_i ) unless filter_params[:taxon_id].blank?
    user_id = filter_params[:user_id] || params[:user_id]
    @user = User.find_by_id(user_id) || User.find_by_login(user_id) unless user_id.blank?
    @is_active = filter_params[:is_active]
    @rank = filter_params[:rank] unless filter_params[:rank].blank?
    
    scope = TaxonFrameworkRelationship.all
    scope = scope.relationships(@relationships) unless @relationships.blank?
    scope = scope.taxon_framework(@taxon_framework) if @taxon_framework
    scope = scope.taxon(@taxon) if @taxon
    scope = scope.by(@user) if @user
    scope = scope.rank(@rank) if @rank
    if @is_active.yesish?
      scope = scope.active
    elsif @is_active.noish?
      scope = scope.inactive
    end
    
    @taxon_framework_relationships = scope.page(params[:page]).
      select("DISTINCT ON (taxon_framework_relationships.id) taxon_framework_relationships.*").
      includes(:external_taxa ,taxa: [:taxon_names, :photos], taxon_framework: :taxon).
      order("taxon_framework_relationships.id DESC")

    respond_to do |format|
      format.html
      format.json do
        taxon_options = { only: [:id, :name, :rank] }
        external_taxon_options = { only: [:name, :url] }
        render json: @taxon_framework_relationships.as_json(
          methods: [:relationship],
          include: [
            { taxa: taxon_options },
            { external_taxa: external_taxon_options }
          ]
        )
      end
    end
  end
  
  def show
    @taxon_framework = @taxon_framework_relationship.taxon_framework
    @downstream_deviations_counts = @taxon_framework_relationship.internal_taxa.map{|it| {internal_taxon: it, count: TaxonFrameworkRelationship.where( "taxon_framework_id = ? AND relationship != 'match'", @taxon_framework.id ).taxon(it).uniq.count } }
  end
  
  def new
    if ( taxon_framework_id = params["taxon_framework_id"] ).present?
      @taxon_framework_relationship = TaxonFrameworkRelationship.new(taxon_framework_id: taxon_framework_id)
    else
      @taxon_framework_relationship = TaxonFrameworkRelationship.new
    end
    @taxon_framework_relationship.external_taxa.new
    if ( taxon_id = params["taxon_id"] ).present? && taxon = Taxon.where( id: taxon_id ).first
      @taxon_framework_relationship.taxa.new( id: taxon_id, rank: nil )
      @taxon_frameworks = [TaxonFramework.joins( "JOIN taxa ON taxa.id = taxon_frameworks.taxon_id" ).
        where( "taxon_frameworks.rank_level <= ? AND taxon_id IN (?)", taxon.rank_level, taxon.ancestor_ids ).
        order( "taxa.rank_level ASC" ).first]
    else
      @taxon_framework_relationship.taxa.new
      @taxon_frameworks = TaxonFramework.includes( :taxon ).all.order( "taxa.name" ).limit( 100 )
    end
  end
  
  def create
    local_params = taxon_framework_relationship_params
    taxa_attributes = local_params["taxa_attributes"]
    local_params.delete("taxa_attributes")
    @taxon_framework_relationship = current_user.taxon_framework_relationships.new( local_params )
    @taxon_framework_relationship.updater = current_user
    
    if @taxon_framework_relationship.taxon_framework.taxon_curators.any? && !@taxon_framework_relationship.taxon_framework.taxon_curators.where( user: current_user ).exists?
      flash[:error] = "only taxon curators can add taxon framework relationships to that taxon framework"
      @taxon_frameworks = TaxonFramework.includes( :taxon ).all.order( "taxa.name" ).limit( 100 )
      render action: :new
      return
    end
    
    if taxa_attributes
      taxa_attributes.values.each do |row|
        if taxon = Taxon.where( id: row["id"] ).first
         if !taxon.taxon_framework_relationship_id.nil? && row["unlink"] == "false"
            flash[:error] = "#{ taxon.name } is already represented in a Taxon Framework Relationship"
            @taxon_frameworks = TaxonFramework.includes( :taxon ).all.order( "taxa.name" ).limit( 100 )
            render action: :new
            return
          end
        end
      end
    end
      
    if @taxon_framework_relationship.save
      if taxa_attributes
        taxa_attributes.values.each do |row|
          if taxon = Taxon.where( id: row["id"] ).first
            if row["unlink"] == "true"
              taxon.update_attribute( :taxon_framework_relationship_id, nil )
            else
              taxon.update_attribute( :taxon_framework_relationship_id, @taxon_framework_relationship.id )
            end
          end
        end
      end
      if taxon = @taxon_framework_relationship.taxa.first
        redirect_to taxonomy_details_for_taxon_path( taxon )
      else
        redirect_to @taxon_framework_relationship
      end
    else
      @taxon_frameworks = TaxonFramework.includes( :taxon ).all.order( "taxa.name" ).limit( 100 )
      render action: :new
    end
  end
  
  def edit
    if @taxon_framework_relationship.taxa.any?
      taxon = @taxon_framework_relationship.taxa.first
      @taxon_frameworks = [TaxonFramework.joins( "JOIN taxa ON taxa.id = taxon_frameworks.taxon_id" ).
          where( "taxon_frameworks.rank_level <= ? AND taxon_id IN (?)", taxon.rank_level, taxon.ancestor_ids ).
          order( "taxa.rank_level ASC" ).first]
    else
      @taxon_frameworks = TaxonFramework.includes( :taxon ).all.order( "taxa.name" ).limit( 100 )
    end
  end

  def update
    local_params = taxon_framework_relationship_params
    taxa_attributes = local_params["taxa_attributes"]
    local_params.delete( "taxa_attributes" )
    local_params.update( updater_id: current_user.id )
    @taxon_framework_relationship = TaxonFrameworkRelationship.find( params[:id] )
    
    if taxa_attributes
      taxa_attributes.values.each do |row|
        if taxon = Taxon.where( id: row["id"] ).first
         if !taxon.taxon_framework_relationship_id.nil? && row["unlink"] == "false" && taxon.taxon_framework_relationship_id != @taxon_framework_relationship.id
            flash[:error] = "#{ taxon.name } is already represented in a Taxon Framework Relationship"
            if @taxon_framework_relationship.taxa.any?
              taxon = @taxon_framework_relationship.taxa.first
              @taxon_frameworks = [TaxonFramework.joins( "JOIN taxa ON taxa.id = taxon_frameworks.taxon_id" ).
                  where( "taxon_frameworks.rank_level <= ? AND taxon_id IN (?)", taxon.rank_level, taxon.ancestor_ids ).
                  order( "taxa.rank_level ASC" ).first]
            else
              @taxon_frameworks = TaxonFramework.includes( :taxon ).all.order( "taxa.name" ).limit( 100 )
            end
            render action: :edit
            return
          end
        end
      end
    end
    
    if @taxon_framework_relationship.update_attributes( local_params )
      if taxa_attributes
        taxa_attributes.values.each do |row|
          if taxon = Taxon.where( id: row["id"] ).first
            if row["unlink"] == "true"
              taxon.update_attribute( :taxon_framework_relationship_id, nil )
            else
              taxon.update_attribute( :taxon_framework_relationship_id, @taxon_framework_relationship.id )
            end
          end
        end
      end
      if taxon = @taxon_framework_relationship.taxa.first
        redirect_to taxonomy_details_for_taxon_path( taxon )
      else
        redirect_to @taxon_framework_relationship
      end
    else
      if @taxon_framework_relationship.taxa.any?
        taxon = @taxon_framework_relationship.taxa.first
        @taxon_frameworks = [TaxonFramework.joins( "JOIN taxa ON taxa.id = taxon_frameworks.taxon_id" ).
            where( "taxon_frameworks.rank_level <= ? AND taxon_id IN (?)", taxon.rank_level, taxon.ancestor_ids ).order( "taxa.rank_level ASC" ).first]
      else
        @taxon_frameworks = TaxonFramework.includes( :taxon ).all.order( "taxa.name" ).limit( 100 )
      end
      render action: :edit
    end
  end
  
  def destroy
    @taxon_framework_relationship = TaxonFrameworkRelationship.find( params[:id] )
    @taxon_framework_relationship.taxa.each do |taxon|
      taxon.update_attribute( :taxon_framework_relationship_id, nil )
    end
    if @taxon_framework_relationship.destroy
      flash[:notice] = "Taxon framework relationship was deleted."
    else
      flash[:error] = "Something went wrong deleting the taxon framework relationship '#{ @taxon_framework_relationship.id }'!"
    end
    redirect_to action: "index"
  end
  
  private
  
  def set_taxon_framework_relationship
    @taxon_framework_relationship = TaxonFrameworkRelationship.where( id: params[:id] ).includes( :taxa, taxon_framework: :source ).first
  end
  
  def taxon_framework_relationship_params
    params.require( :taxon_framework_relationship ).
      permit( :description, :taxon_framework_id, external_taxa_attributes: [:id, :name, :rank, :parent_name, :parent_rank, :url, :_destroy], taxa_attributes: [:id, :unlink] )
  end
  
end

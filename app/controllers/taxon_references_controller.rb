class TaxonReferencesController < ApplicationController
  before_filter :authenticate_user!
  before_action :set_taxon_reference, except: [:index, :new, :create]
  
  layout "bootstrap"
  
  def index
    filter_params = params[:filters] || params
    @relationships = filter_params[:relationships]
    @relationships ||= TaxonReference::RELATIONSHIPS.map{|r| filter_params[r] == "1" ? r : nil}
    @relationships.delete_if{|r| r.blank?}
    @relationships = @relationships.map{|r| r.gsub("_"," ")}
    @concept = Concept.find_by_id(filter_params[:concept_id]) unless filter_params[:concept_id].blank?    
    @concepts = Concept.all
    @taxon = Taxon.find_by_id(filter_params[:taxon_id].to_i) unless filter_params[:taxon_id].blank?
    user_id = filter_params[:user_id] || params[:user_id]
    @user = User.find_by_id(user_id) || User.find_by_login(user_id) unless user_id.blank?
    @is_active = filter_params[:is_active]
    @rank = filter_params[:rank] unless filter_params[:rank].blank?
    
    scope = TaxonReference.all
    scope = scope.relationships(@relationships) unless @relationships.blank?
    scope = scope.concept(@concept) if @concept
    scope = scope.taxon(@taxon) if @taxon
    scope = scope.by(@user) if @user
    scope = scope.rank(@rank) if @rank
    if @is_active == "True"
      scope = scope.active
    elsif @is_active == "False"
      scope = scope.inactive
    end
    
    @taxon_references = scope.page(params[:page]).
      select("DISTINCT ON (taxon_references.id) taxon_references.*").
      includes(:external_taxa ,taxa: [:taxon_names, :photos], concept: :taxon).
      order("taxon_references.id DESC")

    respond_to do |format|
      format.html
      format.json do
        taxon_options = { only: [:id, :name, :rank] }
        external_taxon_options = { only: [:name, :url] }
        render json: @taxon_references.as_json(
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
  end
  
  def new
    @concepts = Concept.all.limit(100)
    if (concept_id = params['concept_id']).present?
      @taxon_reference = TaxonReference.new(concept_id: concept_id)
    else
      @taxon_reference = TaxonReference.new
    end
    @taxon_reference.external_taxa.new
    if (taxon_id = params['taxon_id']).present?
      @taxon_reference.taxa.new(id: taxon_id)
    else
      @taxon_reference.taxa.new
    end
  end
  
  def create
    local_params = taxon_reference_params
    taxa_attributes = local_params["taxa_attributes"]
    local_params.delete("taxa_attributes")
    @taxon_reference = current_user.taxon_references.new(local_params)
    
    if taxa_attributes
      taxa_attributes.values.each do |row|
        if t = Taxon.where(id: row["id"]).first
         if !t.taxon_reference_id.nil? && row["unlink"] == "false"
            flash[:error] = "#{t.name} is already represented in a Taxon Reference"
            @concepts = Concept.all
            render action: :new
            return
          end
        end
      end
    end
      
    if @taxon_reference.save
      if taxa_attributes
        taxa_attributes.values.each do |row|
          if t = Taxon.where(id: row["id"]).first
            if row["unlink"] == "true"
              t.update_attribute(:taxon_reference_id, nil)
            else
              t.update_attribute(:taxon_reference_id, @taxon_reference.id)
            end
          end
        end
      end
      if taxon = @taxon_reference.taxa.first
        redirect_to taxonomy_details_for_taxon_path(taxon)
      else
        redirect_to @taxon_reference
      end
    else
      @concepts = Concept.all
      render action: :new
    end
  end
  
  def edit
    @concepts = Concept.all
  end

  def update
    local_params = taxon_reference_params
    taxa_attributes = local_params["taxa_attributes"]
    local_params.delete("taxa_attributes")
    @taxon_reference = TaxonReference.find( params[:id] )
    
    if taxa_attributes
      taxa_attributes.values.each do |row|
        if t = Taxon.where(id: row["id"]).first
         if !t.taxon_reference_id.nil? && row["unlink"] == "false" && t.taxon_reference_id != @taxon_reference.id
            flash[:error] = "#{t.name} is already represented in a Taxon Reference"
            @concepts = Concept.all
            render action: :edit
            return
          end
        end
      end
    end
    
    if @taxon_reference.update_attributes(local_params)
      if taxa_attributes
        taxa_attributes.values.each do |row|
          if t = Taxon.where(id: row["id"]).first
            if row["unlink"] == "true"
              t.update_attribute(:taxon_reference_id, nil)
            else
              t.update_attribute(:taxon_reference_id, @taxon_reference.id)
            end
          end
        end
      end
      if taxon = @taxon_reference.taxa.first
        redirect_to taxonomy_details_for_taxon_path(taxon)
      else
        redirect_to @taxon_reference
      end
    else
      @concepts = Concept.all
      render action: :edit
    end
  end
  
  def destroy
    @taxon_reference = TaxonReference.find( params[:id] )
    @taxon_reference.taxa.each do |t|
      t.update_attribute(:taxon_reference_id, nil)
    end
    if @taxon_reference.destroy
      flash[:notice] = "Taxon reference was deleted."
    else
      flash[:error] = "Something went wrong deleting the taxon reference '#{@taxon_reference.id}'!"
    end
    redirect_to :action => 'index'
  end
  
  private
  
  def set_taxon_reference
    @taxon_reference = TaxonReference.where(id: params[:id]).includes(:taxa, concept: :source).first
  end
  
  def taxon_reference_params
    params.require(:taxon_reference).permit(:description, :concept_id, external_taxa_attributes: [:id, :name, :rank, :parent_name, :parent_rank, :url, :_destroy], taxa_attributes: [:id, :unlink])
  end
  
end

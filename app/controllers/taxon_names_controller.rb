class TaxonNamesController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  before_filter :load_taxon_name, :only => [:show, :edit, :update, :destroy, :destroy_synonyms]
  before_filter :load_taxon, :except => [:index, :destroy_synonyms]
  before_filter :curator_required_for_sciname, :only => [:create, :update, :destroy, :destroy_synonyms]
  before_filter :load_lexicons, :only => [:new, :create, :edit, :update]
  
  cache_sweeper :taxon_name_sweeper, :only => [:create, :update, :destroy]

  layout "bootstrap"
    
  def index
    find_options = {
      :order => "name ASC",
      :limit => 10
    }

    if params[:q]
      # &q= allows for the searching of keywords by splitting the words into tokens
      find_options[:conditions] = ["name LIKE ?", '%'+params[:q].split(' ').join('%')+'%']
    elsif params[:name]
      # &name= searches for an exact name match.
      find_options[:conditions] = ["name LIKE ?", params[:name]] if params[:name]
    end
    
    if params[:taxon_id]
      find_options[:conditions] = update_conditions(
        find_options[:conditions], 
        ["AND taxon_id = ?", params[:taxon_id].to_i]
      )
    end
    
    find_options[:limit] = params[:limit] if params[:limit]
    
    @taxon_names = TaxonName.find(:all, find_options)
    
    if params[:q] && exact = TaxonName.find_by_name(params[:q])
      @taxon_names.insert(0, exact) unless @taxon_names.include?(exact)
    end
    
    @status = nil
    if params[:include_external]
      if params[:force_external] or (@taxon_names.empty? and params[:q])
        begin
          @external_taxon_names = TaxonName.find_external(params[:q])
          @taxon_names += @external_taxon_names
        rescue Timeout::Error => e
          if @taxon_names.empty? && !@taxon_names.map{|tn| tn.taxon}.include?(nil)
            @status = e.message
          end
        end
      end
    end
    
    # TODO: generate alternate spellings & suggestions using Google, Yahoo, 
    # etc.
    # @suggestions = nil
    # if @taxon_names.empty?
    #   @suggestions = TaxonName.suggest_alternatives_to(query)
    # end
    
    respond_to do |format|
      format.html do
        if params[:autocomplete] # for use by shared/_select_taxa_search partial
          render :layout => false,
                 :partial => 'autocomplete_unordered_list',
                 :locals => {:names => @taxon_names}
          return
        end
        return redirect_to @taxon || @taxon_names.first.taxon
      end
      format.xml  { render :xml => @taxon_names.to_xml(:include => :taxon) }
      format.json do
        if @status
          render(:json => { :status => @status }.to_json)
        else
          render(:json => @taxon_names.to_json(:include => {
            :taxon => {:include => :iconic_taxon}}))
        end
      end
    end
  end

  def taxon
    @taxon_names = @taxon.taxon_names.sort_by{|tn| [tn.position, tn.id]}.reject{|tn| tn.is_scientific?}
    @place_taxon_names = PlaceTaxonName.includes(:taxon_name, :place).where("taxon_names.taxon_id = ?", @taxon).sort_by(&:position)
    place_taxon_name_tn_ids = @place_taxon_names.map(&:taxon_name_id)
    @names_by_place = @place_taxon_names.group_by(&:place).sort_by{|k,v| k.name}
    @global_names = @taxon_names.select{|tn| !place_taxon_name_tn_ids.include?(tn.id)}
    respond_to do |format|
      format.html
    end
  end
  
  def show
    respond_to do |format|
       format.html { redirect_to @taxon }
       format.xml  { render :xml => @taxon_name }
       format.json do
         render :json => @taxon_name.to_json(:include => {:taxon => {
           :include => :iconic_taxon}})
       end
     end
  end
  
  def new
    @taxon_name = TaxonName.new(:taxon => @taxon, :is_valid => true)
  end
  
  def create
    @taxon_name = TaxonName.new(params[:taxon_name])
    @taxon_name.creator = current_user
    @taxon_name.updater = current_user
    
    respond_to do |format|
      if @taxon_name.save
        flash[:notice] = t(:your_name_was_saved)
        format.html { redirect_to taxon_path(@taxon) }
        format.xml  { render :json => @taxon_name, :status => :created, :location => @taxon_name }
      else
        format.html { render :action => "new" }
        format.xml  { render :json => @taxon_name.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def edit
    @synonyms = TaxonName.where(:name => @taxon_name.name).where("id != ?", @taxon_name.id).page(1)
  end
  
  def update
    # Set the last editor
    params[:taxon_name].update(:updater_id => current_user.id)
    
    respond_to do |format|
      if @taxon_name.update_attributes(params[:taxon_name])
        flash[:notice] = t(:taxon_name_was_successfully_updated)
        format.html { redirect_to(taxon_name_path(@taxon_name)) }
        format.json  { head :ok }
      else
        format.html { render :action => 'edit' }
        format.json  { render :json => @taxon_name.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def destroy
    if @taxon_name == @taxon_name.taxon.scientific_name
      msg = <<-EOT
        You can't delete the default scientific name of a taxon. You might
        want to add a new name or create a taxon change instead. See the
        Curator Guide under Help for tips.
      EOT
      flash[:error] = msg
    elsif @taxon_name.destroy
      flash[:notice] = t(:taxon_name_was_deleted)
    else
      flash[:error] = t(:something_went_wrong_deleting_the_taxon_name, :taxon_name => @taxon_name.name)
    end
    respond_to do |format|
      format.html { redirect_to(taxon_path(@taxon_name.taxon)) }
    end
  end

  def destroy_synonyms
    TaxonName.where(:name => @taxon_name.name).where("id != ?", @taxon_name.id).destroy_all
    respond_to do |format|
      format.html do
        flash[:notice] = t(:deleted_synonyms)
        redirect_to(edit_taxon_name_path(@taxon_name))
      end
    end
  end
  
  private
  
  def load_taxon
    @taxon = Taxon.find_by_id(params[:taxon_id].to_i)
    @taxon ||= @taxon_name.taxon if @taxon_name
    @taxon ||= Taxon.find_by_id(params[:id].to_i)
    render_404 and return unless @taxon
    true
  end
  
  def load_taxon_name
    @taxon_name = TaxonName.find_by_id(params[:id].to_i)
    render_404 and return unless @taxon_name
    true
  end
  
  def curator_required_for_sciname
    return true if current_user.is_curator?
    if @taxon_name
      return true if @taxon_name.lexicon != TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    else
      return true if params[:taxon_name].blank?
      return true if params[:taxon_name][:lexicon] != TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    end
    flash[:error] = t(:only_curators_can_add_edit_scientific_names)
    redirect_back_or_default(@taxon)
    false
  end

  def load_lexicons
    @lexicons = Rails.cache.fetch('lexicons', :expires_in => 1.day) do
      [
        TaxonName::LEXICONS.values, 
        TaxonName.select("DISTINCT ON (lexicon) lexicon").map(&:lexicon)
      ].flatten.uniq.reject{|n| n.blank?}.sort
    end
  end
end

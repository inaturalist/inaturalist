module Shared::ListsModule    
  PLAIN_VIEW = 'plain'
  TAXONOMIC_VIEW = 'taxonomic'
  PHOTO_VIEW = 'photo'
  LIST_VIEWS = [PLAIN_VIEW, TAXONOMIC_VIEW, PHOTO_VIEW]
  
  ## RESTful actions ###########################################################
  def index
    redirect_to :controller => 'welcome'
  end
  
  def show
    # Make sure request is being handled by the right controller
    if @list.is_a?(CheckList) && params[:controller] != CheckList.to_s.underscore.pluralize
      return redirect_to @list
    end
    
    @listed_taxa ||= @list.listed_taxa.paginate(@find_options)
    @iconic_taxon_counts = get_iconic_taxon_counts(@list, @iconic_taxa)
    @total_listed_taxa ||= @list.listed_taxa.count
    
    @total_observed_taxa ||= @list.listed_taxa.count(:conditions => "last_observation_id > 0")
    
    @view = params[:view]
    @view = PHOTO_VIEW unless LIST_VIEWS.include?(@view)
    
    case @view
    when TAXONOMIC_VIEW
      ancestor_ids = @listed_taxa.map do |lt|
        # If for some reason taxon_ancestor_ids wasn't set, set it now
        unless lt.taxon_ancestor_ids
          logger.info "[INFO] Updating listed taxa for #{lt.taxon} from lists/#{@list.id}"
          lt.taxon.update_listed_taxa
          lt.reload
        end
        lt.taxon_ancestor_ids.split(',')
      end
      ancestor_ids = ancestor_ids.uniq.compact
      unless ancestor_ids.empty?
        @ancestor_taxa = Taxon.find(ancestor_ids, :include => :taxon_names)
        @ancestor_taxa = @ancestor_taxa.select {|at| at.name != 'Life'}
        @ancestor_taxa.each do |at|
          @listed_taxa << ListedTaxon.new(:list => @list, :taxon => at)
        end
      end

      @listed_taxa = @listed_taxa.sort do |a,b|
        if a.taxon.lft < b.taxon.lft
          -1
        elsif a.taxon.lft > b.taxon.lft
          1
        elsif a.new_record? && !b.new_record?
          -1
        elsif !a.new_record? && b.new_record?
          1
        else
          0
        end
      end
      
      @unclassified = @listed_taxa.select {|lt| !lt.taxon.grafted? }
      @listed_taxa.delete_if {|lt| !lt.taxon.grafted? }
      
    # Default to plain view
    else
      @grouped_listed_taxa = @listed_taxa.group_by do |lt|
        @iconic_taxa_by_id[lt.taxon.iconic_taxon_id]
      end
    end
    
    respond_to do |format|
      format.html
      format.xml do
        render(
          :xml => @list.to_xml(
            :include => {
              :listed_taxa => {
                :include => :taxon}}))
      end
    end
  end
  
  # GET /lists/new
  def new
    @list = List.new(:user => current_user)
    respond_to do |format|
      format.html
    end
  end
  
  # GET /lists/1/edit
  def edit
  end
  
  def create
    # Sometimes STI can be annoying...
    if !params[:list][:type].blank? && Object.const_defined?(params[:list][:type])
      @list = Object.const_get(params[:list][:type]).send(:new, params[:list])
    else
      @list = List.new(params[:list])
    end

    @list.user = current_user
    
    # add rules for all selected taxa
    if params[:taxa] && @list.is_a?(LifeList)
      update_rules(@list, params)
    end
    
    # TODO: add a rule for a place, if one was specified
    
    respond_to do |format|
      if @list.save
        flash[:notice] = 'List was successfully created.'
        format.html { redirect_to(@list) }
      else
        format.html { render :action => "new" }
      end
    end
  end
  
  # PUT /lists/1
  # PUT /lists/1.xml
  def update
    # add rules for all selected taxa
    if params[:taxa] && @list.is_a?(LifeList)
      update_rules(@list, params)
    end
    
    if @list.update_attributes(params[:list])
      flash[:notice] = "List saved."
      redirect_to @list
    else
      render :action => 'edit'
    end
  end
  
  def destroy
    if @list.id == current_user.life_list_id
      flash[:notice] = "Sorry, you can't delete your own life list."
      redirect_to @list and return
    end
    
    @list.destroy
    
    respond_to do |format|
      format.html do
        flash[:notice] = "List deleted."
        redirect_path = if @list.is_a?(CheckList)
          @list.place.check_list
        else
          lists_by_login_url(:login => current_user.login)
        end
        redirect_to(redirect_path)
      end
      format.xml  { head :ok }
    end
  end
  
  def add_taxon_batch
    return redirect_to(@list) unless params[:names]
    @added_taxa = []
    lines = params[:names].split("\n").to_a.map(&:strip)
    if lines.size > 50
      flash[:notice] = "Sorry, you can only add 50 at a time."
      return redirect_to(@list)
    end
    
    @errors = []
    
    lines.each do |name|
      names = TaxonName.paginate(:page => 1, :conditions => {:name => name}, 
        :include => :taxon)
      case names.size
      when 0
        @errors << "#{name}: wasn't found"
      when 1
        listed_taxon = @list.add_taxon(names.first.taxon)
        if listed_taxon.valid?
          @added_taxa << names.first.taxon
        else
          @errors << "#{name}: " + listed_taxon.errors.full_messages.join(', ')
        end
      else
        @errors << "#{name}: matched several different taxa"
      end
    end
    @added_taxa.compact!
    
    flash[:notice] = "Added #{@added_taxa.size} of #{lines.size} names to this list."
    if @errors.size > 0
      flash[:error] = "There were problems with #{@errors.size} of the " +
        "names:<br/> #{@errors.join('<br/>')}."
    end
    redirect_to @list
  end
  
  def taxa
    per_page = params[:per_page]
    per_page = 100 if per_page && per_page.to_i > 100
    conditions = params[:photos_only] ? "flickr_photos.id > 0" : nil
    @taxa = @list.taxa.paginate(:page => params[:page], :per_page => per_page,
      :include => [:iconic_taxon, :flickr_photos, :taxon_names], 
      :conditions => conditions)
    
    respond_to do |format|
      format.html { redirect_to @list }
      format.json do
        @taxa.map! do |taxon|
          taxon.html = render_to_string(:partial => 'taxa/taxon.html.erb', 
            :object => taxon, :locals => {
              :image_options => {:size => 'small'},
              :link_image => true,
              :link_name => true,
              :include_image_attribution => true
          })
          taxon
        end
        render :json => @taxa.to_json(
          :include => :flickr_photos, 
          :methods => [:image_url, :default_name, :common_name, 
            :scientific_name, :html])
      end
    end
  end
  
  private
  
  def get_iconic_taxon_counts(list, iconic_taxa = nil)
    iconic_taxa ||= Taxon.iconic_taxa
    # TODO: pull out check list logic
    iconic_taxon_counts_by_id_hash = if list.is_a?(CheckList) && list.is_default?
      ListedTaxon.count(:all, :include => [:taxon], 
        :conditions => ["place_id = ?", list.place_id],
        :group => "taxa.iconic_taxon_id")
    else
      list.listed_taxa.count(:all, :include => [:taxon], :group => "taxa.iconic_taxon_id")
    end
    iconic_taxa.map do |iconic_taxon|
      [iconic_taxon, iconic_taxon_counts_by_id_hash[iconic_taxon.id.to_s]]
    end
  end
  
  def load_list
    @list = List.find_by_id(params[:id])
    render_404 && return unless @list
    true
  end
  
  # Update the rules for a list given params. Right now we only support the
  # in_taxon? rule, so that's all this does, expecing params[:taxa] to be an
  # array of taxon params.
  def update_rules(list, params)
    params[:taxa].each do |taxon_params|
      list.rules << ListRule.new(
        :operand => Taxon.find(taxon_params[:taxon_id]), 
        :operator => 'in_taxon?'
      ) unless list.rules.map(&:operand_id).include?(taxon_params[:taxon_id])
    end
    list
  end
  
  def load_find_options
    @iconic_taxa = Taxon.iconic_taxa.all(:order => 'rgt')
    @iconic_taxa_by_id = @iconic_taxa.index_by(&:id)
    @find_options = {
      :page => params[:page],
      :per_page => 45,
      :include => [
        :last_observation,
        {:taxon => [:iconic_taxon, :flickr_photos, :taxon_names]}
      ],
      
      # TODO: somehow make the following not cause a filesort...
      :order => 'listed_taxa.lft'
    }
    if params[:taxon]
      @filter_taxon = Taxon.find_by_id(params[:taxon])
      @find_options[:conditions] = ["taxa.iconic_taxon_id = ?", @filter_taxon]
    end
  end
  
  def require_editor
    @list.editable_by?(current_user)
  end
end
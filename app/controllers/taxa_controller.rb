class TaxaController < ApplicationController
  include TaxaHelper
  include Shared::WikipediaModule
  
  before_filter :return_here, :only => [:index, :show, :flickr_tagger]
  before_filter :login_required, :only => [:edit_photos, :update_photos, 
    :update_colors, :tag_flickr_photos, :flickr_photos_tagged, :add_places]
  before_filter :curator_required, 
                :only => [:new, :create, :edit, :update, :destroy, :curation]
  before_filter :load_taxon, :only => [:edit, :update, :destroy, :photos, 
    :children, :graft, :describe, :edit_photos, :update_photos, :edit_colors,
    :update_colors, :add_places]
  before_filter :limit_page_param_for_thinking_sphinx, :only => [:index, 
    :browse, :search]
  verify :method => :post, :only => [:create, :update_photos, 
      :tag_flickr_photos ],
    :redirect_to => { :action => :index }
  verify :method => :put, :only => [ :update, :update_colors ],
    :redirect_to => { :action => :index }
  cache_sweeper :taxon_sweeper, :only => [:update, :destroy, :update_photos]
  rescue_from ActionController::UnknownAction, :with => :try_show
  
  #
  # GET /observations
  # GET /observations.xml
  #
  # @param name: Return all taxa where name is an EXACT match
  # @param q:    Return all taxa where the name begins with q 
  #
  def index
    find_options = {
      :order => "#{Taxon.table_name}.name ASC",
      :include => :taxon_names
    }
    
    @qparams = {}
    if params[:q]
      @qparams[:q] = params[:q]
      find_options[:conditions] =  [ "#{Taxon.table_name}.name LIKE ?", 
                                      '%' + params[:q].split(' ').join('%') + '%' ]
    elsif params[:name]
      @qparams[:name] = params[:name]
      find_options[:conditions] = [ "name = ?", params[:name] ]
    else
      find_options[:conditions] = ["is_iconic = ?", true]
      find_options[:order] = :lft
    end
    if params[:limit]
      @qparams[:limit] = params[:limit]
      find_options[:limit] = params[:limit]
    else
      params[:page_size] ||= 10
      params[:page] ||= 1
      find_options[:page] = params[:page]
      find_options[:per_page] = params[:page_size]
    end
    if params[:all_names] == 'true'
      @qparams[:all_names] = params[:all_names]
      find_options[:include] = [:taxon_names]
      if find_options[:conditions]
        find_options[:conditions][0] += " OR #{TaxonName.table_name}.name LIKE ?"
        find_options[:conditions] << ('%' + params[:q].split(' ').join('%') + '%')
      else
        find_options[:conditions] =  [ "#{TaxonName.table_name}.name LIKE ?", 
                                        '%' + params[:q].split(' ').join('%') + '%' ]
      end
    end

    logger.info(find_options)
    @taxa = Taxon.paginate(:all, find_options)
    
    do_external_lookups
    
    respond_to do |format|
      format.html do # index.html.erb
        flash[:notice] = @status unless @status.blank?
        if params[:q]
          render :action => :search
        else
          @iconic_taxa = Taxon.iconic_taxa.all(
            :include => [:flickr_photos, :taxon_names], :order => :lft)
          @recent = Observation.latest.all(
            :limit => 5, 
            :include => {:taxon => [:taxon_names]},
            :conditions => 'taxon_id IS NOT NULL')
        end
      end
      format.xml  do
        render(:xml => @taxa.to_xml(
          :include => :taxon_names, :methods => [:common_name]))
      end
      format.json do
        render(
          :json => @taxa.to_json(
            :include => :taxon_names, 
            :methods => [:common_name] ) )
      end
    end
  end

  def show
    @taxon ||= Taxon.find_by_id(params[:id]) if params[:id]    
    return render_404 unless @taxon
    
    @taxon_links = TaxonLink.for_taxon(@taxon).all(:include => :taxon)
    @taxon_links.sort! {|a,b| a.taxon.rgt <=> b.taxon.rgt}
    
    @places = Place.paginate(:page => 1,
      :include => :listed_taxa,
      :conditions => ["listed_taxa.taxon_id = ?", @taxon],
      :order => "places.id DESC, places.name ASC"
    )
    @countries = @taxon.places.all(
      :conditions => ["place_type = ?", Place::PLACE_TYPE_CODES['Country']]
    )
    if @countries.size == 1 && @countries.first.code == 'US'
      @us_states = @taxon.places.all(:conditions => [
        "place_type = ? AND parent_id = ?", Place::PLACE_TYPE_CODES['State'], 
        @countries.first.id
      ])
    end
    
    if logged_in?
      @current_user_lists = current_user.lists.all
      @listed_taxa = ListedTaxon.all(
        :include => :list,
        :conditions => [
          "lists.user_id = ? AND listed_taxa.taxon_id = ?", 
          current_user, @taxon
      ])
      @listed_taxa_by_list_id = @listed_taxa.index_by(&:list_id)
      @lists_rejecting_taxon = @current_user_lists.select do |list|
        if list.is_a?(LifeList)
          list.rules.map {|rule| rule.validates?(@taxon)}.include?(false)
        else
          false
        end
      end
    end
    respond_to do |format|
      format.html do
        if @taxon.name == 'Life' && !@taxon.parent_id
          return redirect_to(:action => 'index')
        end
        render :action => 'show'
      end
      format.xml do
        render :xml => @taxon.to_xml(
          :include => [:taxon_names, :iconic_taxon], 
          :methods => [:common_name]
        )
      end
      format.json do
        render(:json => @taxon.to_json(
          :include => [:taxon_names, :iconic_taxon], 
          :methods => [:common_name])
        )
      end
      format.node { render :json => jit_taxon_node(@taxon) }
    end
  end

  def new
    @taxon = Taxon.new
  end

  def create
    @taxon = Taxon.new(params[:taxon])
    @taxon.creator = current_user
    @taxon.updater = current_user
    if @taxon.save
      flash[:notice] = 'Taxon was successfully created.'
      redirect_to :action => 'show', :id => @taxon
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    @taxon.flickr_photos = retreive_flickr_photos
    if params[:taxon_names]
      TaxonName.update(params[:taxon_names].keys, params[:taxon_names].values)
    end
    if params[:taxon][:colors]
      @taxon.colors = Color.find(params[:taxon].delete(:colors))
    end
    
    parent_error = false
    if params[:taxon][:parent_id]
      begin
        if parent = Taxon.find_by_id(params[:taxon][:parent_id])
          @taxon.move_to_child_of(parent)
        end
      rescue StandardError => e
        flash[:error] = "A problem occurred while setting the parent: " + 
                        e.message
        parent_error = true
      end
    end
    
    # Set the last editor
    params[:taxon].update(:updater_id => current_user.id)
    
    if @taxon.update_attributes(params[:taxon]) && !parent_error
      flash[:notice] = 'Taxon was successfully updated.'
      redirect_to taxon_path(@taxon)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @taxon.destroy
    flash[:notice] = "Taxon deleted."
    redirect_to :action => 'index'
  end
  

## Custom actions ############################################################

  #
  # Search for taxa using full-text indexed search
  #
  def search
    @qparams = params
    @page = params[:page] ? params[:page].to_i : 1
    per_page = params[:per_page] ? params[:per_page].to_i : 20
    per_page = 100 if per_page > 100
    if params[:q]
      @taxa = Taxon.search(params[:q], 
        :include => [:taxon_names, :flickr_photos, :iconic_taxon],
        :page => @page, :per_page => per_page)
    end
    
    do_external_lookups
    
    respond_to do |format|
      format.html
      format.xml  { render :xml => @taxa.to_xml(:include => :taxon_names) }
      format.json do
        render :json => @taxa.to_json(
          :include => [:iconic_taxon, :taxon_names, :flickr_photos],
          :methods => [:common_name, :image_url, :default_name])
      end
    end
  end
  
  # /taxa/browse?q=bird
  # /taxa/browse?q=bird&places=1,2&colors=4,5
  # TODO: /taxa/browse?q=bird&places=usa-ca-berkeley,usa-ct-clinton&colors=blue,black
  def browse
    @q = params[:q]
    drill_params = {}
    
    if params[:iconic_taxa] && @iconic_taxa_ids = params[:iconic_taxa].split(',')
      @iconic_taxa_ids.map!(&:to_i)
      @iconic_taxa = Taxon.find(@iconic_taxa_ids)
      drill_params[:iconic_taxon_id] = @iconic_taxa_ids
    end
    if params[:places] && @place_ids = params[:places].split(',')
      @place_ids.map!(&:to_i)
      @places = Place.find(@place_ids)
      drill_params[:places] = @place_ids
    end
    if params[:colors] && @color_ids = params[:colors].split(',')
      @color_ids.map!(&:to_i)
      @colors = Color.find(@color_ids)
      drill_params[:colors] = @color_ids
    end
    
    # TS seems to not return all the place facets if you specify per_page
    # without conditions, not really sure why.  This makes pagination a little
    # weird (pp = 20 if no facets selected, pp = 24 if they are), but I think
    # we can live with that for now
    @facets = if drill_params.blank?
      Taxon.facets(@q, :page => params[:page])
    else
      page = params[:page] ? params[:page].to_i : 1
      per_page = params[:per_page] ? params[:per_page].to_i : 24
      per_page = 100 if per_page > 100
      Taxon.facets(@q, :page => page, :per_page => per_page,
        :conditions => drill_params, 
        :include => [:taxon_names, :flickr_photos])
    end
    
    if @facets[:iconic_taxon_id]
      @faceted_iconic_taxa = Taxon.all(
        :conditions => ["id in (?)", @facets[:iconic_taxon_id].keys],
        :include => [:taxon_names, :flickr_photos],
        :order => 'lft'
      )
      @faceted_iconic_taxa_by_id = @faceted_iconic_taxa.index_by(&:id)
    end
    
    if @facets[:colors]
      @faceted_colors = Color.all(:conditions => ["id in (?)", @facets[:colors].keys])
      @faceted_colors_by_id = @faceted_colors.index_by(&:id)
    end
    
    if @facets[:places]
      @faceted_places = if @places.blank?
        Place.paginate(:page => 1, :order => "name", :conditions => [
          "id in (?) && place_type = ?", 
          @facets[:places].keys, Place::PLACE_TYPE_CODES['Country']
        ])
      else
        Place.all(:order => "name", :conditions => [
          "id in (?) AND parent_id IN (?)", 
          @facets[:places].keys, @places.map(&:id)
        ])
      end
      @faceted_places_by_id = @faceted_places.index_by(&:id)
    end
    
    @taxa = @facets.for(drill_params)
    
    do_external_lookups
    
    respond_to do |format|
      format.html do
        flash[:notice] = @status unless @status.blank?
      end
      format.json do
        render :json => @taxa.to_json(
          :include => [:iconic_taxon, :taxon_names, :flickr_photos],
          :methods => [:common_name, :image_url, :default_name])
      end
    end
  end
  
  def occur_in
    @taxa = Taxon.occurs_in(params[:swlng], params[:swlat], params[:nelng], 
                            params[:nelat], params[:startDate], params[:endDate])
    @taxa.sort! do |a,b| 
      (a.common_name ? a.common_name.name : a.name) <=> (b.common_name ? b.common_name.name : b.name)
    end
    respond_to do |format|
      format.html
      format.json do
        render :text => @taxa.to_json(
                 :methods => [:id, :common_name] )
      end
    end
  end
  
  #
  # List child taxa of this taxon
  #
  def children
    respond_to do |format|
      format.html { redirect_to taxon_path(@taxon) }
      format.xml do
        render :xml => @taxon.children.to_xml(
                :include => :taxon_names, :methods => [:common_name] )
      end
      format.json do
        render(
          :json => @taxon.children.to_json(
            :include => :taxon_names, 
            :methods => [:common_name] ) )
      end
    end
  end
  
  def photos
    @photos = @taxon.photos(:limit => 24)
    render :layout => false
  end
  
  def edit_photos
    render :layout => false
  end
  
  def add_places
    if request.post?
      search_for_places
      @listed_taxa = @taxon.listed_taxa.all(:conditions => ["place_id IN (?)", @places], :group => "place_id")
      @listed_taxa_by_place_id = @listed_taxa.index_by(&:place_id)
      render :update do |page|
        page[dom_id(@taxon, 'place_selector_places')].replace_html(
          :partial => 'add_to_place_link', :collection => @places)
      end
      return
    end
    render :layout => false
  end
  
  def update_photos
    @taxon.flickr_photos = retreive_flickr_photos
    if @taxon.save
      flash[:notice] = "Taxon photos updated!"
    else
      flash[:error] = "Something went wrong saving the photos: #{@taxon.errors.full_messages}"
    end
    redirect_to taxon_path(@taxon)
  end
  
  def describe
    @title = @taxon.name
    wikipedia
  end
  
  def update_colors
    unless params[:taxon] && params[:taxon][:color_ids]
      redirect_to @taxon
    end
    params[:taxon][:color_ids].delete_if(&:blank?)
    @taxon.colors = Color.find(params[:taxon].delete(:color_ids))
    respond_to do |format|
      if @taxon.save
        format.html { redirect_to @taxon }
        format.js do
          render :text => "Colors updated."
        end
      else
        format.html do
          flash[:error] = "There was a problem saving those colors: " +
            @taxon.errors.full_messages.join(', ')
          redirect_to @taxon
        end
        format.js do
          render :update do |page|
            page.alert "There were some problems saving those colors: " +
              @taxon.errors.full_messages.join(', ')
          end
        end
      end
    end
  end
  
  
  def graft
    if @taxon.name_provider.blank?
      @error_message = "Sorry, you can only automatically graft taxa that " + 
        "were imported from an external name provider."
    else
      begin
        Ratatosk.graft(@taxon)
      rescue Timeout::Error => e
        @error_message = e.message
      rescue RatatoskGraftError => e
        @error_message = e.message
      end
    end
    
    respond_to do |format|
      format.html do
        flash[:error] = @error_message if @error_message
        redirect_to(edit_taxon_path(@taxon))
      end
      format.js do
        if @error_message
          render :status => :unprocessable_entity, :text => @error_message
        else
          render :text => "Taxon grafted to #{@taxon.parent.name}"
        end
      end
    end
  end
  
  def curation
    @flags = Flag.paginate(:page => params[:page], 
      :conditions => "resolved = false AND flaggable_type = 'Taxon'")
    life = Taxon.find_by_name('Life')
    ungrafted_roots = Taxon.roots.all(:conditions => ["id != ?", life])
    @ungrafted =  ungrafted_roots.map{|ur| ur.self_and_descendants}.flatten
  end
  
  def flickr_tagger    
    net_flickr = get_net_flickr
    if logged_in? && current_user.flickr_identity
      net_flickr.auth.token = current_user.flickr_identity.token
    end
    
    if !params[:flickr_photo_id].blank?
      begin
        original = net_flickr.photos.get_info(params[:flickr_photo_id])
        if @flickr_photo = FlickrPhoto.new_from_net_flickr(original)
          if @taxa = @flickr_photo.to_taxa(:flickr => flickr, :fp => original)
            @taxon = @taxa.sort_by(&:lft).last
          end
        end
      rescue Net::Flickr::APIError
        flash[:notice] = "Sorry, that Flickr photo either doesn't exist or " +
          "you don't have permission to view it."
      end
    end
    
    @taxon ||= Taxon.find_by_id(params[:id]) if params[:id]
    @taxon ||= Taxon.find_by_id(params[:taxon_id]) if params[:taxon_id]
    
    @tags = []
    if @taxon
      if @taxon.grafted?
        @tags += @taxon.self_and_ancestors.map do |taxon|
          unless taxon.root?
            name_pieces = taxon.name.split
            name_pieces.delete('subsp.')
            if name_pieces.size == 3
              ["taxonomy:species=#{name_pieces[1]}", "taxonomy:trinomial=#{name_pieces.join(' ')}"]
            elsif name_pieces.size == 2
              ["taxonomy:species=#{name_pieces[1]}", "taxonomy:binomial=#{taxon.name.strip}"]
            else
              ["taxonomy:#{taxon.rank}=#{taxon.name.strip}", taxon.name.strip]
            end
          end
        end.flatten.compact
      else
        name_pieces = @taxon.name.split
        name_pieces.delete('subsp.')
        if name_pieces.size == 3
          @tags << "taxonomy:trinomial=#{name_pieces.join(' ')}"
          @tags << "taxonomy:binomial=#{name_pieces[0]} #{name_pieces[1]}"
        elsif name_pieces.size == 2
          @tags << "taxonomy:binomial=#{@taxon.name.strip}"
        else
          @tags << "taxonomy:#{@taxon.rank}=#{@taxon.name.strip}"
        end
      end
      @tags += @taxon.taxon_names.map{|tn| tn.name.strip if tn.is_valid?}.compact
      @tags += @taxon.taxon_names.map do |taxon_name|
        unless taxon_name.lexicon == TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
          "taxonomy:common=#{taxon_name.name.strip}"
        end
      end.compact.flatten
      
      @tags = @tags.compact.flatten.uniq
    end
    
    respond_to do |format|
      format.html
      format.json { render :json => @tags}
    end
  end
  
  def tag_flickr_photos
    # Post tags to flickr
    unless params[:flickr_photos] && !params[:flickr_photos].blank?
      flash[:notice] = "You didn't select any photos to tag!"
      redirect_to :action => 'flickr_tagger' and return
    end
    
    unless logged_in? && current_user.flickr_identity
      flash[:notice] = "Sorry, you need to be signed in and have a " + 
        "linked Flickr account to post tags directly to Flickr."
      redirect_to :action => 'flickr_tagger' and return
    end
    
    get_flickraw
    
    params[:flickr_photos].each do |flickr_photo_id|
      begin
        flickr.photos.addTags(:photo_id => flickr_photo_id, 
          :tags => params[:tags], 
          :auth_token => current_user.flickr_identity.token)
      rescue FlickRaw::FailedResponse => e
        if e.message =~ /Insufficient permissions/
          auth_url = FlickRaw.auth_url :perms => 'write'
          flash[:notice] = "iNat can't add tags to your photos until " + 
            "Flickr knows you've given us permission.  " + 
            "<a href=\"#{auth_url}\">Click here to authorize iNat to add tags</a>."
        else
          flash[:error] = "Something went wrong trying to to post those tags: #{e.message}"
        end
        redirect_to :action => 'flickr_tagger' and return
      rescue Exception => e
        flash[:error] = "Something went wrong trying to to post those tags: #{e.message}"
        redirect_to :action => 'flickr_tagger' and return
      end
    end
    
    flash[:notice] = "Your photos have been tagged!"
    redirect_to :action => 'flickr_photos_tagged', 
      :flickr_photos => params[:flickr_photos], :tags => params[:tags]
  end
  
  def flickr_photos_tagged
    get_flickraw
    
    @tags = params[:tags]
    
    @flickr_photos = params[:flickr_photos].map do |flickr_photo_id|
      fp = flickr.photos.getInfo(:photo_id => flickr_photo_id, 
        :auth_token => current_user.flickr_identity.token)
      FlickrPhoto.new_from_flickraw(fp, :user => current_user)
    end

    
    @observations = current_user.observations.all(
      :include => :flickr_photos,
      :conditions => [
        "flickr_photos.flickr_native_photo_id IN (?)", 
        @flickr_photos.map(&:flickr_native_photo_id)
      ]
    )
    @imported_flickr_native_photo_id = {}
    @observations.each do |observation|
      observation.flickr_photos.each do |flickr_photo|
        @imported_flickr_native_photo_id[flickr_photo.flickr_native_photo_id] = true
      end
    end
  end
  
  def tree
    @life = Taxon.find_by_name('Life')
    @life = Taxon.iconic_taxa.first.parent unless @life
  end
  
## Protected / private actions ###############################################
  private
  
  #
  # Find locally cached photos or get new ones from flickr based on form
  # params.
  #
  def retreive_flickr_photos
    return [] if params[:flickr_photos].nil?

    flickr = get_net_flickr
    photos = []
    params[:flickr_photos].reject {|i| i.empty?}.uniq.each do |photo_id|
      if fp = FlickrPhoto.find_by_flickr_native_photo_id(photo_id)
        photos << fp 
      else
        fp = flickr.photos.get_info(photo_id)
        photos << FlickrPhoto.new_from_net_flickr(fp)
      end
    end
    photos
  end
  
  def load_taxon
    render_404 unless @taxon = Taxon.find_by_id(params[:id])
  end
  
  # Try to find a taxon from urls like /taxa/Animalia or /taxa/Homo_sapiens
  def try_show(exception)
    raise exception if params[:action].blank?
    name = params[:action].split('_').join(' ')
    taxa = Taxon.all(:conditions => ["name = ?", name], :limit => 2) unless @taxon
    @taxon ||= taxa.first if taxa.size == 1
    unless @taxon
      taxon_names = TaxonName.all(:conditions => ["name = ?", name], :limit => 2) # (tn = TaxonName.all(:conditions => ["name = ?", name], :limit => 2)) ? tn.taxon : nil
      @taxon = taxon_names.first.taxon if taxon_names.size == 1
    end
    
    # Redirect to a canonical form
    return redirect_to :action => name.split.join('_') if @taxon && params[:action].split.size > 1
    
    # TODO: if multiple exact matches, render a disambig page with status 300 (Mulitple choices)
    unless @taxon
      # TODO: render custom 404 page with search & import options
      return redirect_to :action => 'search', :q => name
    else
      show
    end
  end
  
  def do_external_lookups
    return unless logged_in? && 
    return unless params[:force_external] || (params[:include_external] && @taxa.empty?)
    @external_taxa = []
    logger.info("DEBUG: Making an external lookup...")
    fe_params = params[:external_src] ? { :src => params[:external_src] } : {}
    ext_names = []
    begin
      ratatosk = case params[:external_src]
      when 'ubio'
        Ratatosk::Ratatosk.new(:name_providers => [Ratatosk::NameProviders::UBioNameProvider.new])
      when 'col'
        Ratatosk::Ratatosk.new(:name_providers => [Ratatosk::NameProviders::ColNameProvider.new])
      else
        Ratatosk
      end
      
      # fetch names and save them
      ratatosk.find(params[:q]).each do |ext_name|
        unless ext_name.valid?
          if existing_taxon = ratatosk.find_existing_taxon(ext_name.taxon)
            ext_name.taxon = existing_taxon
          end
        end
        ext_name.save
        ext_names << ext_name if ext_name.valid?
      end
    rescue Timeout::Error => e
      @status = e.message if @external_taxa.empty?
    rescue NameProviderError => e
      @status = e.message if @external_taxa.empty?
    end
    
    @external_taxa = Taxon.find(ext_names.map(&:taxon_id))
    
    # graft in the background at a lower priority than this process
    unless @external_taxa.empty?
      spawn(:nice => 7) do
        @external_taxa.each do |external_taxon|
          unless external_taxon.grafted?
            logger.debug "[DEBUG] Grafting #{external_taxon}..."
            Ratatosk.graft(external_taxon)
          end
        end
      end
    end
    
    unless @external_taxa.empty?
      @taxa = WillPaginate::Collection.create(1, @external_taxa.size) do |pager|
        pager.replace(@external_taxa)
        pager.total_entries = @external_taxa.size
      end
    end
  end
end

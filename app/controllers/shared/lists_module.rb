module Shared::ListsModule    
  PLAIN_VIEW = 'plain'
  TAXONOMIC_VIEW = 'taxonomic'
  PHOTO_VIEW = 'photo'
  LIST_VIEWS = [PLAIN_VIEW, TAXONOMIC_VIEW, PHOTO_VIEW]
  
  ## RESTful actions ###########################################################
  def index
    if logged_in?
      redirect_to lists_by_login_path(current_user.login)
    else
      redirect_to :controller => 'welcome'
    end
  end
  
  def show
    @view = params[:view] || params[:view_type]
    @unpaginated_listed_taxa ||= ListedTaxon.filter_by_list(@list.id)
    respond_to do |format|
      format.html do
        # Make sure request is being handled by the right controller
        if @list.is_a?(CheckList) && params[:controller] != CheckList.to_s.underscore.pluralize
          return redirect_to @list
        end

        if @q = params[:q]
          @search_taxon_ids = Taxon.search_for_ids(@q, :per_page => 1000)
          @find_options[:conditions] = update_conditions(
            @find_options[:conditions], ["AND listed_taxa.taxon_id IN (?)", @search_taxon_ids])
        end

        set_scopes unless @listed_taxa.present?

        @taxon_names_by_taxon_id = set_taxon_names_by_taxon_id

        @iconic_taxon_counts = get_iconic_taxon_counts(@list, @iconic_taxa, @unpaginated_listed_taxa)
        @total_listed_taxa ||= @listed_taxa.count 
        @total_observed_taxa ||= @listed_taxa.with_observation.count
        @view = PHOTO_VIEW unless LIST_VIEWS.include?(@view)

        case @view
        when TAXONOMIC_VIEW
          @unclassified = @listed_taxa.select {|lt| !lt.taxon.grafted? }
          @listed_taxa = @listed_taxa.delete_if {|lt| !lt.taxon.grafted? }
          ancestor_ids = @listed_taxa.map{|lt| lt.taxon.ancestor_ids[1..-1]}.flatten.uniq
          ancestors = Taxon.find_all_by_id(ancestor_ids, :include => :taxon_names)
          taxa_to_arrange = (ancestors + @listed_taxa.map(&:taxon)).sort_by{|t| "#{t.ancestry}/#{t.id}"}
          @arranged_taxa = Taxon.arrange_nodes(taxa_to_arrange)
          @listed_taxa_by_taxon_id = @listed_taxa.index_by(&:taxon_id)

        # Default to plain view
        else
          @grouped_listed_taxa = @listed_taxa.group_by do |lt|
            @iconic_taxa_by_id[lt.taxon.iconic_taxon_id]
          end
        end

        if job_id = Rails.cache.read("add_taxa_from_observations_job_#{@list.id}")
          @add_taxa_from_observations_job = Delayed::Job.find_by_id(job_id)
        end

        @listed_taxa_editble_by_current_user = @list.listed_taxa_editable_by?(current_user)
        @taxon_rule = @list.rules.detect{|lr| lr.operator == 'in_taxon?' && lr.operand.is_a?(Taxon)}

        if @list.show_obs_photos
          load_listed_taxon_photos
        end
        
        if logged_in?
          @current_user_lists = current_user.lists.all(:limit => 100)
        end

        if @representative_listed_taxon = @list.listed_taxa.order("listed_taxa.observations_count DESC").includes(:taxon => {:taxon_photos => :photo}).first
          @representative_photo = if @photos_by_listed_taxon_id && (p = @photos_by_listed_taxon_id[@representative_listed_taxon.id])
            p
          else
            @representative_listed_taxon.taxon.default_photo
          end
        end
      end
      
      format.csv do
        path_for_taxonomic_csv = "public/lists/#{@list.to_param}.taxonomic.csv"
        path_for_normal_csv = "public/lists/#{@list.to_param}.csv"
        if @list.listed_taxa.count < 1000
          path = if @view == "taxonomic"
            @list.generate_csv(:path => path_for_taxonomic_csv, :taxonomic => true)
          else
            @list.generate_csv(:path => path_for_normal_csv)
          end
          render :file => path
        else
          job_id = Rails.cache.read(@list.generate_csv_cache_key(:view => @view))
          job = Delayed::Job.find_by_id(job_id)
          if job
            # Still working
          else
            # no job id, no job, let's get this party started
            Rails.cache.delete(@list.generate_csv_cache_key(:view => @view))
            job = if @view == "taxonomic"
              @list.delay.generate_csv(:path => path_for_taxonomic_csv, :taxonomic => true)
            else
              @list.delay.generate_csv(:path => path_for_normal_csv)
            end
            Rails.cache.write(@list.generate_csv_cache_key(:view => @view), job.id, :expires_in => 1.hour)
          end
          prevent_caching
          render :status => :accepted, :text => "This file takes a little while to generate.  It should be ready shortly at #{request.url}"
        end
      end
      
      format.json do
        @find_options[:order] = "observations_count DESC" if params[:order_by].blank?
        set_scopes unless @listed_taxa.present?
        @listed_taxa ||= @list.listed_taxa.paginate(@find_options)
        render :json => {
          :list => @list,
          :listed_taxa => @listed_taxa.as_json(
            :except => [:manually_added, :updater_id, :observation_month_counts, :taxon_range_id, :source_id],
            :include => { :taxon => Taxon.default_json_options }
          ),
          :current_page => @listed_taxa.current_page,
          :total_pages => @listed_taxa.total_pages,
          :total_entries => @listed_taxa.total_entries
        }
      end
    end
  end
  
  # GET /lists/new
  def new
    @list = List.new(:user => current_user, :title => params[:title])
    respond_to do |format|
      format.html
    end
  end
  
  # GET /lists/1/edit
  def edit
    @taxon_rule = @list.rules.detect{|lr| lr.operator == 'in_taxon?'}
  end

  def batch_edit
    if params[:flow_task_id] && @flow_task = FlowTask.find_by_id(params[:flow_task_id])
      @flow_task_outputs = @flow_task.outputs.order(:id)
      @listed_taxa_by_id = ListedTaxon.includes(:taxon => :taxon_names).
        where("id IN (?)", @flow_task_outputs.map(&:resource_id).compact).
        index_by(&:id)
      @listed_taxa = []
      @flow_task_outputs.each do |ft|
        lt = @listed_taxa_by_id[ft.resource_id]
        unless lt
          name, description, occurrence_status, establishment_means = ft.extra[:row] if ft.extra
          lt = if ft.extra && ft.extra[:error].to_s =~ /already/
            @list.listed_taxa.find_by_taxon_id(ft.extra[:taxon_id]) unless ft.extra[:taxon_id].blank?
          end
          lt ||= ListedTaxon.new(:list => @list)
          lt.description = description unless description.blank?
          lt.occurrence_status_level = if ListedTaxon::OCCURRENCE_STATUS_LEVELS_BY_NAME[primary_occurrence_status.to_s.downcase]
            ListedTaxon::OCCURRENCE_STATUS_LEVELS_BY_NAME[primary_occurrence_status.to_s.downcase]
          else
            lt.occurrence_status_level
          end
          lt.establishment_means = if ListedTaxon::ESTABLISHMENT_MEANS.include?(primary_establishment_means.to_s.downcase)
            establishment_means.downcase
          else
            lt.establishment_means
          end
          lt.extra = ft.extra
        end
        @listed_taxa << lt
      end
    else
      @listed_taxa = @list.listed_taxa.includes(:taxon => :taxon_names).page(params[:page]).per_page(200)
    end
  end
  
  def create
    # Sometimes STI can be annoying...
    klass = Object.const_get(params[:list].delete(:type)) rescue List
    klass = List unless klass.ancestors.include?(List)
    list_params = params[:list]
    list_params = params[klass.to_s.underscore] if list_params.blank?
    @list = klass.new(list_params)

    @list.user = current_user
    
    # add rules for all selected taxa
    if params[:taxa] && @list.is_a?(LifeList)
      update_rules(@list, params)
    end
    
    # TODO: add a rule for a place, if one was specified
    
    respond_to do |format|
      if @list.save
        flash[:notice] = t(:list_was_successfully_created)
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
    
    list_attributes = params[:list] || params[:life_list] || params[:check_list]
    
    if @list.update_attributes(list_attributes)
      flash[:notice] = t(:list_saved)
      redirect_to @list
    else
      render :action => 'edit'
    end
  end
  
  def destroy
    if @list.id == current_user.life_list_id
      flash[:notice] = t(:sorry_you_cant_delete_your_own_life_list)
      redirect_to @list and return
    end
    
    @list.destroy
    
    respond_to do |format|
      format.html do
        flash[:notice] = t(:list_deleted)
        redirect_path = if @list.is_a?(CheckList)
          @list.place.check_list || @list.place
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
    @lines = params[:names].split("\n").to_a.map{|n| n.strip.gsub(/\s+/, " ")}.delete_if(&:blank?)
    @max = 1000
    @batch_size = 50
    
    if @lines.size > @max
      flash[:notice] = t(:sorry_you_can_only_add_1000_at_a_time)
      return redirect_to(@list)
    end
    
    @errors = []
    @lines_taxa = []
    @lines.each_with_index do |name, i|
      
      # If we're past 50, just add nil and assume we'll deal with it later
      if i > @batch_size
        @lines_taxa << [name, nil]
        next
      end
      
      taxon_names = TaxonName.includes(:taxon).
        where("lower(taxon_names.name) = ?", name.to_s.downcase).
        page(1)
      case taxon_names.size
      when 0
        @lines_taxa << [name, "not found"]
      when 1
        listed_taxon = @list.add_taxon(taxon_names.first.taxon, :user_id => current_user.id, :manually_added => true)
        if listed_taxon.valid?
          @lines_taxa << [name, listed_taxon]
        else
          @lines_taxa << [name, listed_taxon.errors.full_messages.to_sentence]
        end
      else
        @lines_taxa << [name, "matched several different taxa"]
      end
    end
    
    respond_to do |format|
      format.html { render :template => "lists/add_taxon_batch" }
      format.json do
        json = @lines_taxa.map do |name, item|
          {
            :name => name,
            :parameterized_name => name.parameterize,
            :item => item, 
            :html => view_context.render_in_format(:html, :partial => "lists/add_taxon_batch_line", :object => [name, item])
          }
        end
        render :json => json
      end
    end
  end
  
  def taxa
    per_page = params[:per_page]
    per_page = 100 if per_page && per_page.to_i > 100
    conditions = params[:photos_only] ? "photos.id IS NOT NULL" : nil
    @taxa = @list.taxa.paginate(:page => params[:page], :per_page => per_page,
      :include => [:iconic_taxon, :photos, :taxon_names], 
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
          :include => :photos, 
          :methods => [:image_url, :default_name, :common_name, 
            :scientific_name, :html])
      end
    end
  end
  
  private
  
  def get_iconic_taxon_counts(list, iconic_taxa = nil, listed_taxa = nil)
    iconic_taxa ||= Taxon::ICONIC_TAXA
    listed_taxa ||= @listed_taxa
    listed_taxa_iconic_taxon_ids = listed_taxa.map{|lt| lt.taxon.iconic_taxon_id }
    iconic_taxa.map do |iconic_taxon|
      taxon_count = listed_taxa_iconic_taxon_ids.count(iconic_taxon.id)
      [iconic_taxon, taxon_count]
    end
  end

  
  def load_list
    @list = List.find_by_id(params[:id].to_i)
    @list ||= List.find_by_id(params[:list_id].to_i)
    render_404 && return unless @list
    true
  end
  
  # Update the rules for a list given params. Right now we only support the
  # in_taxon? rule, so that's all this does, expecing params[:taxa] to be an
  # array of taxon params.
  def update_rules(list, params)
    params[:taxa].each do |taxon_params|
      taxon = Taxon.find_by_id(taxon_params[:taxon_id].to_i)
      next unless taxon
      list.build_taxon_rule(taxon)
    end
    list
  end
  
  def set_find_options
    @iconic_taxa = Taxon::ICONIC_TAXA
    @iconic_taxa_by_id = @iconic_taxa.index_by(&:id)
    page = params[:page].to_i
    page = 1 if page == 0
    per_page = params[:per_page].to_i
    per_page = 45 if per_page <= 0
    per_page = 200 if per_page > 200
    @find_options = {
      :page => page,
      :per_page => per_page,
      :include => [
        :last_observation,
        {:taxon => [:iconic_taxon, :photos, :taxon_names]}
      ]
    }
    set_options_order
  end

  def set_scopes
    apply_list_scopes
    apply_checklist_scopes if @list.is_a?(CheckList)
    @listed_taxa ||= @unpaginated_listed_taxa.paginate(@find_options)
  end

  def apply_list_scopes
    if filter_by_taxon?
      # This scope uses an eager load which won't load all 2nd order associations (e.g. taxon names), so they'll have to loaded when needed
      @find_options[:include] = [
        :last_observation, 
        {:taxon => [:iconic_taxon, :photos]}
      ]
      self_and_ancestor_ids = [@filter_taxon.ancestor_ids, @filter_taxon.id].flatten.join('/')
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.filter_by_taxon(@filter_taxon.id, self_and_ancestor_ids)
    end
    if filter_by_iconic_taxon?
      iconic_taxon_id = Taxon.find_by_id(params[:iconic_taxon]).try(:id)
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.filter_by_iconic_taxon(iconic_taxon_id)
    end
  end

  def apply_checklist_scopes
    if filter_by_param?(params[:taxonomic_status])
      @taxonomic_status = params[:taxonomic_status]
      unless @taxonomic_status=="all"
        taxonomic_status_for_scope = params["taxonomic_status"] == "active"
        @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_taxonomic_status(taxonomic_status_for_scope)
      end
    else
      @taxonomic_status = "active"
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_taxonomic_status(true)
    end
    if with_observations?
      @observed = 't'
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.confirmed
    elsif with_no_observations?
      @observed = 'f'
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.unconfirmed
    end
    if filter_by_param?(params[:rank])
      @rank = params[:rank]
      if @rank=="species"
        @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_species
      elsif @rank=="leaves"
        @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_leaves(@unpaginated_listed_taxa.to_sql)
      end
    else 
      @rank = "species"
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_species
    end
    if filter_by_param?(params[:establishment_means])
      @establishment_means = params[:establishment_means]
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_establishment_means(params[:establishment_means])
    end
    if filter_by_param?(params[:occurrence_status])
      @occurrence_status = params[:occurrence_status]
      if @occurrence_status == "absent"
        @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_occurrence_status_levels_approximating_absent
      elsif @occurrence_status=="not_absent"
        @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_occurrence_status_levels_approximating_present
      end
    else
      @occurrence_status = "not_absent"
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_occurrence_status_levels_approximating_present
    end
    if with_threatened?
      @threatened = 't'
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.with_threatened_status
    elsif without_threatened?
      @threatened = 'f'
      @unpaginated_listed_taxa = @unpaginated_listed_taxa.without_threatened_status
    end
  end

  def set_options_order
    @find_options[:order] = case params[:order_by]
    when "name"
      order = params[:order]
      order = "asc" unless %w(asc desc).include?(params[:order])
      "taxa.name #{order}"
    when "observations_count"
      order = params[:order]
      order = "desc" unless %w(asc desc).include?(params[:order])
      "listed_taxa.observations_count #{order}"
    else
      # TODO: somehow make the following not cause a filesort...
      "taxon_ancestor_ids || '/' || listed_taxa.taxon_id"
    end
  end

  def filter_by_param?(param_name)
    !([nil, "on"].include?(param_name))
  end

  def filter_by_taxon?
    !!(params[:taxon] && @filter_taxon = (Taxon.find_by_id(params[:taxon].to_i) || Taxon.where("lower(name) = ?", params[:taxon].to_s.downcase).first))
  end

  def filter_by_iconic_taxon?
    !!params[:iconic_taxon]
  end

  def with_threatened?
    [true, 't', 'true', '1', 'y', 'yes'].include?(params[:threatened])
  end

  def without_threatened?
    [false, 'f', 'false', '0', 'n', 'no'].include?(params[:threatened])
  end

  def with_no_observations?
    [false, 'f', 'false', '0', 'n', 'no'].include?(params[:observed])
  end

  def with_observations?
    [true, 't', 'true', '1', 'y', 'yes'].include?(params[:observed])
  end

  def require_editor
    @list.editable_by?(current_user)
  end

  def require_listed_taxa_editor
    @list.listed_taxa_editable_by?(current_user)
  end
  
  def load_listed_taxon_photos
    # override
  end
  
  def set_taxon_names_by_taxon_id
    listed_taxa = @listed_taxa.map(&:taxon)
    taxa = [listed_taxa, @taxa, @iconic_taxa].flatten.compact
    TaxonName.all(:conditions => [ "taxon_id IN (?)", taxa]).group_by(&:taxon_id)
  end
end







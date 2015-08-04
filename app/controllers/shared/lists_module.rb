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
    @find_options = set_find_options
    @view = params[:view] || params[:view_type]
    @observable_list = observable_list(@list)
    @q = params[:q] unless params[:q].blank?
    @search_taxon_ids = set_search_taxon_ids(@q)
    unless @search_taxon_ids.blank?
      @find_options[:conditions] = update_conditions(@find_options[:conditions], ["AND listed_taxa.taxon_id IN (?)", @search_taxon_ids])
    end

    if place_based_list?(@list)
      if @place = set_place(@observable_list)
        @other_check_lists = get_other_check_lists(@observable_list, @place)
      end
    end

    if default_checklist?(@list) 
      listed_taxa = handle_default_checklist_setup(@list, @q, @search_taxon_ids) 
      main_list = set_scopes(@list, @filter_taxon, listed_taxa)
    elsif place_based_project_list?(@list) && !with_observations?
      taxon_for_rule_filter = Taxon.find(@list.project.project_observation_rules.find{|por| por.operator == "in_taxon?"}.operand_id) rescue nil
      acceptable_taxa_from_list = taxon_for_rule_filter ? (taxon_for_rule_filter.descendant_ids + [taxon_for_rule_filter.id]) : nil

      @ignore_observed_filter_for_place = true if params[:observed] == 'f'
      listed_taxa_with_duplicates = set_scopes_for_place_based_project_list(@list, @q, @filter_taxon, @search_taxon_ids, acceptable_taxa_from_list) 

      query = listed_taxa_with_duplicates.select([:id, :taxon_id, :place_id, :last_observation_id])
      results = ActiveRecord::Base.connection.select_all(query)

      if params[:observed] == 'f'
        listed_taxa_hash = results.inject({}) do |aggregator, listed_taxon|
          aggregator["#{listed_taxon['taxon_id']}"] = listed_taxon['id'] if (!already_in_list_and_observed_and_not_place_based(results, listed_taxon) && not_yet_in_list_and_unobserved(aggregator, listed_taxon) || !already_in_list_and_not_place_based(results, listed_taxon)) 
          aggregator
        end
        @total_observed_taxa = 0
      else
        listed_taxa_hash = results.inject({}) do |aggregator, listed_taxon|
          aggregator["#{listed_taxon['taxon_id']}"] = listed_taxon['id'] if (aggregator["#{listed_taxon['taxon_id']}"].nil? || listed_taxon['place_id'].nil?)
          aggregator
        end
      end
      listed_taxa_ids = listed_taxa_hash.values.map(&:to_i)


      listed_taxa = listed_taxa_with_duplicates.where("listed_taxa.id IN (?)", listed_taxa_ids)


      main_list = set_scopes(@list, @filter_taxon, listed_taxa)

      @listed_taxa = main_list.where(@find_options[:conditions]).
        includes(@find_options[:include]).
        paginate(page: @find_options[:page], per_page: @find_options[:per_page]).
        order(@find_options[:order])

      @total_listed_taxa =  main_list.count
      @total_observed_taxa ||= main_list.confirmed_and_not_place_based.count
      @iconic_taxon_counts = get_iconic_taxon_counts_for_place_based_project(@list, @iconic_taxa, @listed_taxa)
    else
      main_list = set_scopes(@list, @filter_taxon, @list.listed_taxa)
    end
    @listed_taxa ||= main_list.where(@find_options[:conditions]).
      includes(@find_options[:include]).
      paginate(page: @find_options[:page], per_page: @find_options[:per_page]).
      order(@find_options[:order])

    respond_to do |format|
      format.html do
        # Make sure request is being handled by the right controller
        if @list.is_a?(CheckList) && params[:controller] != CheckList.to_s.underscore.pluralize
          return redirect_to @list
        end
        @allow_batch_adding = allow_batch_adding(@list, current_user)


        @taxon_names_by_taxon_id = set_taxon_names_by_taxon_id(@listed_taxa, @iconic_taxa, @taxa)
        @iconic_taxon_counts ||= get_iconic_taxon_counts(@list, @iconic_taxa, main_list)
        @total_listed_taxa ||= @listed_taxa.count
        @total_observed_taxa ||= @listed_taxa.confirmed.count
        @view = PHOTO_VIEW unless LIST_VIEWS.include?(@view)

        # preload all primary listed taxa. Would be nicer to do this in the
        # CheckListsController, but it needs to happen after build_query
        if @list.is_a?(CheckList)
          primary_listed_taxa = @listed_taxa.select(&:primary_listing)
          non_primary_listed_taxa = @listed_taxa - primary_listed_taxa
          primary_listed_taxa += ListedTaxon.
            where(:primary_listing => true, :place_id => @list.place_id).
            where("taxon_id IN (?)", non_primary_listed_taxa.map(&:taxon_id))
          @primary_listed_taxa_by_taxon_id = primary_listed_taxa.index_by(&:taxon_id)
        end

        case @view
        when TAXONOMIC_VIEW
          @unclassified = @listed_taxa.to_a.select {|lt| !lt.taxon.grafted? }
          @listed_taxa = @listed_taxa.to_a.delete_if {|lt| !lt.taxon.grafted? }
          ancestor_ids = @listed_taxa.map{|lt| lt.taxon.ancestor_ids[1..-1]}.flatten.uniq
          ancestors = Taxon.where(id: ancestor_ids).includes(:taxon_names)
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
          @current_user_lists = current_user.lists.limit(100)
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
          if path
            render :file => path
          else
            render :status => :accepted, :text => "This file takes a little while to generate.  It should be ready shortly at #{request.url}"
          end
        else
          job_id = Rails.cache.read(@list.generate_csv_cache_key(:view => @view))
          job = Delayed::Job.find_by_id(job_id)
          if job
            # Still working
          else
            # no job id, no job, let's get this party started
            Rails.cache.delete(@list.generate_csv_cache_key(:view => @view))
            job = if @view == "taxonomic"
              @list.delay(:priority => NOTIFICATION_PRIORITY).generate_csv(:path => path_for_taxonomic_csv, :taxonomic => true)
            else
              @list.delay(:priority => NOTIFICATION_PRIORITY).generate_csv(:path => path_for_normal_csv)
            end
            Rails.cache.write(@list.generate_csv_cache_key(:view => @view), job.id, :expires_in => 1.hour)
          end
          prevent_caching
          render :status => :accepted, :text => "This file takes a little while to generate.  It should be ready shortly at #{request.url}"
        end
      end
      
      format.json do
        @listed_taxa ||= @list.listed_taxa.paginate(@find_options)
        if @listed_taxa.respond_to?(:scoped) && params[:order_by].blank?
          @listed_taxa = @listed_taxa.reorder("listed_taxa.observations_count DESC")
        end
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
          lt.occurrence_status_level = if ListedTaxon::OCCURRENCE_STATUS_LEVELS_BY_NAME[lt.primary_occurrence_status.to_s.downcase]
            ListedTaxon::OCCURRENCE_STATUS_LEVELS_BY_NAME[lt.primary_occurrence_status.to_s.downcase]
          else
            lt.occurrence_status_level
          end
          lt.establishment_means = if ListedTaxon::ESTABLISHMENT_MEANS.include?(establishment_means.to_s.downcase)
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
      respond_to do |format|
        format.html do
          flash[:notice] = t(:sorry_you_cant_delete_your_own_life_list)
          redirect_to @list
        end
      end
      return
    end

    if @list.is_a?(ProjectList)
      respond_to do |format|
        format.html do
          flash[:notice] = t(:you_cant_delete_a_project_list)
          redirect_to @list
        end
      end
      return
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
  def set_place(list)
    unless p = list.place
      p = list.project.place if list.is_a?(ProjectList)
    end
    p
  end
  
  def get_other_check_lists(list, place)
    place.check_lists.where("id != ?", list.id).limit(500)
  end
  
  def set_scopes_for_place_based_project_list(list, q, filter_taxon, search_taxon_ids, acceptable_taxa_from_list)
    unpaginated_listed_taxa = ListedTaxon.from_place_or_list(list.project.place_id, list.id)
    unpaginated_listed_taxa = unpaginated_listed_taxa.with_occurrence_status_levels_approximating_present
    if acceptable_taxa_from_list
      unpaginated_listed_taxa = unpaginated_listed_taxa.acceptable_taxa(acceptable_taxa_from_list)
    end
    if q
      unpaginated_listed_taxa = unpaginated_listed_taxa.filter_by_taxa(search_taxon_ids)
    end
    unpaginated_listed_taxa
  end

  def set_scopes_for_place_based_project_list_with_observed_from_place(list, q, filter_taxon, search_taxon_ids, acceptable_taxa_from_list)
    unpaginated_listed_taxa = ListedTaxon.from_place_or_list_with_observed_from_place(list.project.place_id, list.id)
    if acceptable_taxa_from_list
      unpaginated_listed_taxa = unpaginated_listed_taxa.acceptable_taxa(acceptable_taxa_from_list)
    end
    if q
      unpaginated_listed_taxa = unpaginated_listed_taxa.filter_by_taxa(search_taxon_ids)
    end
    unpaginated_listed_taxa
  end

  def handle_default_checklist_setup(list, q, search_taxon_ids)
    unpaginated_listed_taxa = ListedTaxon.find_listed_taxa_from_default_list(list.place_id)
    unless q.blank?
      unpaginated_listed_taxa = unpaginated_listed_taxa.filter_by_taxa(search_taxon_ids)
    end
    unpaginated_listed_taxa
  end

  def set_search_taxon_ids(q)
    return [] if q.blank?
    @search_taxon_ids = Taxon.elastic_search(
      where: { "names.name": @q }, fields: :id).per_page(1000).map(&:id)
  end

  def get_iconic_taxon_counts(list, iconic_taxa = nil, listed_taxa = nil)
    return [ ] if listed_taxa.nil?
    iconic_taxa = Taxon::ICONIC_TAXA
    counts = ListedTaxon.from("(#{listed_taxa.to_sql}) AS listed_taxa").joins(:taxon).group("taxa.iconic_taxon_id").count
    iconic_taxa.map do |iconic_taxon|
      [iconic_taxon, counts[iconic_taxon.id] || 0]
    end
  end

  def get_iconic_taxon_counts_for_place_based_project(list, iconic_taxa = nil, listed_taxa = nil)
    iconic_taxa ||= Taxon::ICONIC_TAXA
    counts = listed_taxa.joins(:taxon).group("taxa.iconic_taxon_id").count
    iconic_taxa.map do |iconic_taxon|
      [iconic_taxon, counts[iconic_taxon.id] || 0]
    end
  end
  
  def load_list #before_filter
    @list = List.find_by_id(params[:id].to_i)
    @list ||= List.find_by_id(params[:list_id].to_i)
    List.preload_associations(@list, :user)
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

  def set_iconic_taxa #before_filter
    @iconic_taxa = Taxon::ICONIC_TAXA
    @iconic_taxa_by_id = @iconic_taxa.index_by(&:id)
  end
  
  def set_find_options
    page = params[:page].to_i
    page = 1 if page == 0
    per_page = params[:per_page].to_i
    if per_page <= 0
      per_page = request.format.json? ? 200 : 45
    end
    per_page = 200 if per_page > 200
    find_options = {
      :page => page,
      :per_page => per_page,
      :include => [
        :list, :user, :first_observation, :last_observation,
        {:taxon => [:iconic_taxon, :photos, :taxon_names]}
      ]
    }
    # This scope uses an eager load which won't load all 2nd order associations (e.g. taxon names), so they'll have to loaded when needed
    find_options[:include] = [ :last_observation, {:taxon => [:iconic_taxon, :photos]} ] if filter_by_taxon?

    set_options_order(find_options)
  end

  def set_scopes(list, filter_taxon, unpaginated_listed_taxa)
    unpaginated_listed_taxa = apply_list_scopes(list, unpaginated_listed_taxa, filter_taxon)
    unpaginated_listed_taxa = apply_checklist_scopes(list, unpaginated_listed_taxa) if list.is_a?(CheckList)
    unpaginated_listed_taxa
  end

  def apply_list_scopes(list, unpaginated_listed_taxa, filter_taxon)
    if filter_by_taxon?
      self_and_ancestor_ids = [filter_taxon.ancestor_ids, filter_taxon.id].flatten.join('/')
      unpaginated_listed_taxa = unpaginated_listed_taxa.filter_by_taxon(filter_taxon.id, self_and_ancestor_ids)
    end
    
    if filter_by_iconic_taxon? && (params[:taxonomic_status] != "all")
      unpaginated_listed_taxa = apply_iconic_taxon_and_taxonomic_status_filters(unpaginated_listed_taxa)
    elsif filter_by_iconic_taxon?
      unpaginated_listed_taxa = apply_iconic_taxon_filter(unpaginated_listed_taxa)
    elsif params[:taxonomic_status] != "all"
      unpaginated_listed_taxa = apply_taxonomic_status_filter(unpaginated_listed_taxa)
    end
    if params[:taxonomic_status] == "all"
      @taxonomic_status = "all"
    end

    if with_observations?
      @observed = 't'
      unpaginated_listed_taxa = unpaginated_listed_taxa.confirmed
    elsif with_no_observations?
      @observed = 'f'
      unless (@ignore_observed_filter_for_place)
        unpaginated_listed_taxa = unpaginated_listed_taxa.unconfirmed
      end
    end

    if filter_by_param?(params[:rank])
      @rank = params[:rank]
      if @rank == "species"
        unpaginated_listed_taxa = unpaginated_listed_taxa.with_species
      elsif @rank == "leaves"
        unpaginated_listed_taxa = unpaginated_listed_taxa.with_leaves(unpaginated_listed_taxa.to_sql)
      end
    # Scott wants this so places/show and check_lists/show have matching
    # counts. I think it's dumb - kueda 20140218, unhappy, desiring sleep
    elsif list.is_a?(CheckList)
      @rank = "species"
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_species
    else
      @rank = "all"
    end
    unless @search_taxon_ids.blank?
      unpaginated_listed_taxa = unpaginated_listed_taxa.where("listed_taxa.taxon_id IN (?)", @search_taxon_ids)
    end
    unpaginated_listed_taxa
  end

  def apply_iconic_taxon_filter(unpaginated_listed_taxa)
    if filter_by_iconic_taxon?
      @iconic_taxon_id = Taxon.find_by_id(params[:iconic_taxon]).try(:id)
      unpaginated_listed_taxa = unpaginated_listed_taxa.filter_by_iconic_taxon(@iconic_taxon_id)
    end
    unpaginated_listed_taxa
  end

  def apply_taxonomic_status_filter(unpaginated_listed_taxa)
    if filter_by_param?(params[:taxonomic_status])
      @taxonomic_status = params[:taxonomic_status]
      unless @taxonomic_status == "all"
        taxonomic_status_for_scope = params["taxonomic_status"] == "active"
        unpaginated_listed_taxa = unpaginated_listed_taxa.with_taxonomic_status(taxonomic_status_for_scope)
      end
    else
      @taxonomic_status = "active"
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_taxonomic_status(true)
    end
    unpaginated_listed_taxa
  end

  def apply_iconic_taxon_and_taxonomic_status_filters(unpaginated_listed_taxa)
    @iconic_taxon_id = Taxon.find_by_id(params[:iconic_taxon]).try(:id)
    if filter_by_param?(params[:taxonomic_status])
      @taxonomic_status = params[:taxonomic_status]
      unless @taxonomic_status == "all"
        taxonomic_status_for_scope = params["taxonomic_status"] == "active"
      end
    else
      @taxonomic_status = "active"
      taxonomic_status_for_scope = true
    end
    unpaginated_listed_taxa = unpaginated_listed_taxa.with_taxonomic_status_and_iconic_taxon(taxonomic_status_for_scope, @iconic_taxon_id)
  end

  def apply_checklist_scopes(list, unpaginated_listed_taxa)
    if filter_by_param?(params[:establishment_means])
      @establishment_means = params[:establishment_means]
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_establishment_means(params[:establishment_means])
    end
    if filter_by_param?(params[:occurrence_status])
      @occurrence_status = params[:occurrence_status]
      if @occurrence_status == "absent"
        unpaginated_listed_taxa = unpaginated_listed_taxa.with_occurrence_status_levels_approximating_absent
      elsif @occurrence_status=="not_absent"
        unpaginated_listed_taxa = unpaginated_listed_taxa.with_occurrence_status_levels_approximating_present
      end
    elsif params[:occurrence_status] != 'any'
      @occurrence_status = "not_absent"
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_occurrence_status_levels_approximating_present
    end
    if with_threatened?
      @threatened = 't'
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_threatened_status(list.place_id)
    end
    unpaginated_listed_taxa
  end

  def set_options_order(find_options)
    find_options[:order] = case params[:order_by]
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
    find_options
  end

  def filter_by_param?(param_name)
    !([nil, "on", "any"].include?(param_name))
  end

  def filter_by_taxon?
    return false if params[:taxon].blank?
    @filter_taxon ||= Taxon.find_by_id(params[:taxon].to_i) || Taxon.where("lower(name) = ?", params[:taxon].to_s.downcase).first
    !@filter_taxon.blank?
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
  
  def set_taxon_names_by_taxon_id(listed_taxa, iconic_taxa, taxa)
    taxon_ids = [
      listed_taxa ? listed_taxa.map(&:taxon_id) : nil,
      taxa ? taxa.map(&:id) : nil,
      iconic_taxa ? iconic_taxa.map(&:id) : nil
    ].flatten.uniq.compact
    TaxonName.where("taxon_id IN (?)", taxon_ids).group_by(&:taxon_id)
  end

  def observable_list(list)
    (list.type == "ProjectList" && list.project.show_from_place) ? list.project.place.check_list : list
  end

  def allow_batch_adding(list, current_user)
    if(list.type == "ProjectList")
      list.editable_by?(current_user) && !list.project.show_from_place
    else
      list.editable_by?(current_user)
    end
  end

  def place_based_list?(list)
    list.type == "CheckList" || place_based_project_list?(list)
  end

  def place_based_project_list?(list)
    list.type == "ProjectList" && list.project.show_from_place
  end

  def default_checklist?(list)
    list.type=="CheckList" && list.is_default?
  end

  def already_in_list_and_observed_and_not_place_based(results, listed_taxon)
    results.find{|lt| (listed_taxon['taxon_id'] == lt['taxon_id'] && lt['last_observation_id'] && lt['place_id'].nil? )}
  end
  
  def not_yet_in_list_and_unobserved(aggregator, listed_taxon)
    aggregator["#{listed_taxon['taxon_id']}"].nil? && (listed_taxon['last_observation_id'].nil?)
  end

  def already_in_list_and_not_place_based(results, listed_taxon)
    results.find{|lt| (lt['taxon_id']==listed_taxon['taxon_id'] && lt['place_id'].nil?) }
  end
end

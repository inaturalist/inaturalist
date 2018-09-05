class IdentificationsController < ApplicationController
  before_action :doorkeeper_authorize!, :only => [ :create, :update, :destroy ], :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :except => [:by_login], :unless => lambda { authenticated_with_oauth? }
  before_filter :load_user_by_login, :only => [:by_login]
  load_only = [ :show, :edit, :update, :destroy ]
  before_filter :load_identification, :only => load_only
  blocks_spam :only => load_only, :instance => :identification
  before_filter :require_owner, :only => [:edit, :update, :destroy]
  cache_sweeper :comment_sweeper, :only => [:create, :update, :destroy, :agree]
  caches_action :bold, :expires_in => 6.hours, :cache_path => Proc.new {|c| 
    c.params.merge(:sequence => Digest::MD5.hexdigest(c.params[:sequence]))
  }

  def index
    per_page = 50
    search_params = {
      order_by: "id",
      order: "desc",
      per_page: per_page,
      page: params[:page] || 1,
      d1: params[:d1],
      d2: params[:d2]
    }
    if Identification::CATEGORIES.include?( params[:category] )
      search_params[:category] = params[:category]
    end
    if params[:user_id]
      if user = ( User.find_by_id( params[:user_id] ) || User.find_by_login( params[:user_id] ) )
        search_params[:user_id] = user.id
      end
    end
    if params[:current].blank? || params[:current].yesish?
      search_params[:current] = "true"
    elsif params[:current].noish?
      search_params[:current] = "false"
    else
      search_params[:current] = "any"
    end
    if params[:for] == "others"
      search_params[:own_observation] = "false"
    elsif params[:for] == "self"
      search_params[:own_observation] = "true"
    end
    search_params[:taxon_id] = params[:taxon_id] if params[:taxon_id]
    api_response = INatAPIService.identifications(search_params)
    ids = Identification.where(id: api_response.results.map{ |r| r["id"] }).
      includes(:observation, :user, { taxon: [ { taxon_names: :place_taxon_names }, :photos ] }).order(id: :desc)
    Observation.preload_for_component(ids.map(&:observation), logged_in: logged_in?)
    @identifications = WillPaginate::Collection.create(params[:page] || 1, per_page,
      api_response.total_results) do |pager|
      pager.replace(ids)
    end


    counts_response = INatAPIService.identifications_categories(search_params)
    @counts = Hash[counts_response.results.map{ |r| [ r["category"], r["count"] ] }]
    respond_to do |format|
      format.html { render layout: "bootstrap" }
    end
  end
    
  def show
    redirect_to observation_url(@identification.observation, :anchor => "identification-#{@identification.id}")
  end
  
  def by_login
    block_if_spammer(@selected_user) && return
    params[:page] = params[:page].to_i
    params[:page] = 1 unless params[:page] > 0
    user_filter = { term: { "identifications.user.id": @selected_user.id } }
    ownership_filter = { term: { "identifications.own_observation": false } }
    date_parts = Identification.conditions_for_date("col", params[:on])
    # only if conditions_for_date determines a valid range will it return
    # an array of [ condition_to_interpolate, min_date, max_date ]
    if date_parts.length == 3
      date_filters = [
        { range: { "identifications.created_at": { gte: date_parts[1] } } },
        { range: { "identifications.created_at": { lte: date_parts[2] } } }
      ]
    end
    result = Observation.elastic_search(
      filters: [ { nested: {
        path: "identifications",
        query: { bool: { must: [ user_filter, date_filters, ownership_filter ].flatten.compact } }
      } } ],
      size: limited_per_page,
      from: (params[:page] - 1) * limited_per_page,
      sort: {
        "identifications.created_at": {
          order: "desc",
          mode: "max",
          nested_path: "identifications",
          nested_filter: user_filter
        }
      }
    )
    # pluck the proper Identification IDs from the obs results
    ids = result.response.hits.hits.map do |h|
      ( h._source.identifications).detect{ |i|
        i.user.id == @selected_user.id
      }
    end.compact.map{ |i| i.id }
    # fetch the Identification instances and preload
    instances = Identification.where(id: ids).order(id: :desc).includes(
      { observation: [ :user, :photos, { taxon: [{taxon_names: :place_taxon_names}, :photos] } ] },
      { taxon: [{taxon_names: :place_taxon_names}, :photos] },
      :user
    )
    # turn the instances into a WillPaginate Collection
    @identifications = WillPaginate::Collection.create(params[:page], limited_per_page,
      result.response.hits.total) do |pager|
      pager.replace(instances.to_a)
    end
    respond_to do |format|
      format.html do
        @identifications_by_obs_id = @identifications.index_by(&:observation_id)
        @observations = @identifications.collect(&:observation)
        @other_ids = Identification.where(observation_id: @observations).where("user_id != ?", @selected_user).
          includes(:observation, :taxon)
        @other_id_stats = {}
        @other_ids.group_by(&:observation).each do |obs, ids|
          user_ident = @identifications_by_obs_id[obs.id]
          agreements = ids.select do |ident|
            ident.in_agreement_with?(user_ident)
          end
          @other_id_stats[obs.id] = {
            :num_agreements => agreements.size,
            :num_disagreements => ids.size - agreements.size
          }
        end
      end
      format.json do
        pagination_headers_for( @identifications )
        @identifications.each do |i|
          i.taxon.current_user = current_user if i.taxon && current_user
          i.observation.taxon.current_user = current_user if i.observation.taxon && current_user
          i.observation.localize_place = current_user.try(:place) || @site.place
          i.observation.localize_locale = current_user.try(:locale) || @site.locale
        end
        taxon_options = {
          only: [:id, :name, :rank],
          methods: [:default_name, :photo_url, :iconic_taxon_name]
        }
        render json: @identifications.as_json( include: [
          {
            taxon: taxon_options
          }, 
          {
            observation: {
              only: [:id, :species_guess],
              methods: [:iconic_taxon_name],
              include: {
                taxon: taxon_options,
                photos: {
                  only: [:id, :square_url, :thumb_url, :small_url, :medium_url, :large_url],
                  methods: [:license_code, :attribution]
                }
              }
            }
          }
        ] )
      end
    end
  end
  
  # POST identification_url
  def create
    @identification = Identification.new(params[:identification])
    @identification.user = current_user
    if @identification.taxon.blank? && params[:taxa_search_form_taxon_name]
      taxon_name = TaxonName.find_by_name(params[:taxa_search_form_taxon_name])
      @identification.taxon = taxon_name.taxon if taxon_name
    end
    if params[:vision]
      @identification.prefers_vision = true
    end
    respond_to do |format|
      duplicate_key_violation = false
      begin
        @identification.save
      rescue PG::Error, ActiveRecord::RecordNotUnique => e
        raise e unless e =~ /index_identifications_on_current/
        duplicate_key_violation = true
      end
      if @identification.valid? && duplicate_key_violation == false
        format.html do
          flash[:notice] = t(:identification_saved)
          if params[:return_to]
            return redirect_to(params[:return_to])
          end
          redirect_to @identification.observation and return
        end
        
        format.json do
          Observation.refresh_es_index
          @identification.html = view_context.render_in_format(:html, :partial => "identifications/identification")
          render :json => @identification.to_json(
            :methods => [:html, :vision], 
            :include => {
              :observation => {:methods => [:iconic_taxon_name]}
            }
          ).html_safe
        end
      else
        format.html do
          flash[:error] = t(:there_was_a_problem_saving_your_identification, :error => @identification.errors.full_messages.join(', '))
          if params[:return_to]
            return redirect_to(params[:return_to])
          end
          redirect_to @identification.observation || root_url
          return
        end
        
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @identification.errors.full_messages }
        end
      end
    end
  end
  
  def edit
    render layout: "bootstrap"
  end
  
  def update
    if @identification.update_attributes(params[:identification])
      msg = t(:identification_updated)
      respond_to do |format|
        format.html do
          flash[:notice] = msg
          redirect_to @identification.observation
        end
        format.json do
          Observation.refresh_es_index
          render :json => @identification
        end
      end
    else
      msg = t(:there_was_a_problem_saving_your_identification, :error => @identification.errors.full_messages.join(', '))
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to @identification.observation
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @identification.errors.full_messages}
        end
      end
    end
  end
  

  # DELETE identification_url
  def destroy
    observation = @identification.observation
    if params[:delete]
      @identification.destroy
    else
      @identification.update_attributes( current: false )
    end
    respond_to do |format|
      format.html do
        flash[:notice] = if @identification.frozen?
          t(:identification_deleted)
        else
          t(:identification_withdrawn)
        end
        redirect_to observation
      end
      format.js do
        Observation.refresh_es_index
        render :status => :ok, :json => nil
      end
      format.json do
        Observation.refresh_es_index
        render :status => :ok, :json => nil
      end
    end
  end
  
## Custom actions ############################################################

  # Agree with an identification
  def agree
    unless @observation = Observation.find_by_id(params[:observation_id])
      render_404
      return
    end
    @old_identification = @observation.identifications.by(current_user).current.last
    if @old_identification && @old_identification.taxon_id == params[:taxon_id].to_i
      @identification = @old_identification
    else
      @identification = Identification.new(
        :user => current_user,
        :taxon_id => params[:taxon_id].to_i,
        :observation_id => params[:observation_id]
      )
    end
    
    respond_to do |format|
      duplicate_key_violation = false
      begin
        @identification.save
      rescue PG::Error, ActiveRecord::RecordNotUnique => e
        raise e unless e =~ /index_identifications_on_current/
        duplicate_key_violation = true
      end
      if @identification.valid? && duplicate_key_violation == false
        format.html { agree_respond_to_html }
        format.json do
          @identification.html = view_context.render_in_format(:html, :partial => "identifications/identification")
          render :json => @identification.to_json(:methods => [:html])
        end
      else
        format.html { agree_respond_to_html_failure }
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @identification.errors.full_messages }
        end
      end
    end
  end

  def bold
    url = "http://boldsystems.org/index.php/Ids_xml?db=#{params[:db]}&sequence=#{params[:sequence]}"
    xml = begin
      Nokogiri::XML(open(url))
    rescue URI::InvalidURIError => e
      "<error>#{e.message}</error>"
    end
    respond_to do |format|
      format.xml { render :xml => xml }
    end
  end
  
  private
  
  def agree_respond_to_html
    flash[:notice] = t(:identification_saved)
    if params[:return_to]
      return redirect_to(params[:return_to])
    end
    redirect_to @identification.observation
  end
  
  def agree_respond_to_html_failure
    flash[:error] = t(:there_was_a_problem_saving_your_identification, :error => @identification.errors.full_messages.join(', '))
    if params[:return_to]
      return redirect_to(params[:return_to])
    end
    redirect_to @identification.observation
  end
  
  def load_identification
    render_404 unless @identification = Identification.find_by_id(params[:id])
  end
  
  def require_owner
    unless logged_in? && @identification.user_id == current_user.id
      redirect_to_hell
    end
  end
end

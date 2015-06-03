# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  include Ambidextrous
  
  has_mobile_fu :ignore_formats => [:tablet, :json, :widget]
  around_filter :catch_missing_mobile_templates

  # many people try random URLs like wordpress login pages with format .php
  # for any format we do not recognize, make sure we render a proper 404
  rescue_from ActionController::UnknownFormat, with: :render_404

  helper :all # include all helpers, all the time
  protect_from_forgery
  before_filter :whitelist_params
  around_filter :set_time_zone
  before_filter :return_here, :only => [:index, :show, :by_login]
  before_filter :return_here_from_url
  before_filter :user_logging
  after_filter :user_request_logging
  before_filter :remove_header_and_footer_for_apps
  before_filter :login_from_param
  before_filter :set_site
  before_filter :set_ga_trackers
  before_filter :set_request_locale

  PER_PAGES = [10,30,50,100,200]
  HEADER_VERSION = 16
  
  alias :logged_in? :user_signed_in?

  # set the locale for the current session. If the user is
  # logged in, also update their preferred locale in the DB
  def set_locale
    if I18N_SUPPORTED_LOCALES.include?( params[:locale] )
      if logged_in?
        current_user.update_attribute(:locale, params[:locale])
      end
      session[:locale] = params[:locale]
    end
    redirect_back_or_default( root_url )
  end

  private

  # Store the URI of the current request in the session.
  #
  # We can return to this location by calling #redirect_back_or_default.
  def store_location
    session[:return_to] = request.fullpath
  end

  def set_site
    @site ||= Site.find_by_id(CONFIG.site_id) if CONFIG.site_id
    @site ||= Site.where("url LIKE '%#{request.host}%'").first
  end

  def set_ga_trackers
    return true unless request.format.blank? || request.format.html?
    trackers = []
    if CONFIG.google_analytics
      if CONFIG.google_analytics.trackers
        trackers += CONFIG.google_analytics.trackers
      elsif CONFIG.google_analytics.tracker_id
        trackers << ['default', CONFIG.google_analytics.tracker_id]
      end
    end
    if @site && !@site.google_analytics_tracker_id.blank?
      trackers << [@site.name.gsub(/\s+/, '').underscore, @site.google_analytics_tracker_id]
    end
    request.env['inat_ga_trackers'] = trackers unless trackers.blank?
  end

  def set_request_locale
    # use params[:locale] for single-request locale settings,
    # otherwise use the session, user's preferred, or site default locale
    I18n.locale = params[:locale] || session[:locale] ||
      current_user.try(:locale) || I18n.default_locale
    I18n.locale = current_user.try(:locale) if I18n.locale.blank?
    I18n.locale = I18n.default_locale if I18n.locale.blank?
  end

  # Redirect to the URI stored by the most recent store_location call or
  # to the passed default.  Set an appropriately modified
  #   after_filter :store_location, :only => [:index, :new, :show, :edit]
  # for any controller you want to be bounce-backable.
  def redirect_back_or_default(default)
    back_url = session[:return_to] # || request.env['HTTP_REFERER']
    if back_url && ![request.path, request.url].include?(back_url)
      redirect_to back_url, :status => :see_other
    else
      redirect_to default, :status => :see_other
    end
    session[:return_to] = nil
  end
  
  #
  # Update an ActiveRecord conditions array with new conditions
  #
  def update_conditions(conditions, new_condition)
    conditions ||= {}
    updated_conditions = conditions.clone rescue nil
    if updated_conditions.blank?
      if new_condition.is_a? String
        new_condition.sub!(/^\s*(or|OR|and|AND)\s*/, '')
      elsif new_condition[0].is_a? String
        new_condition[0].sub!(/^\s*(or|OR|and|AND)\s*/, '')    
      end
      updated_conditions = new_condition
    elsif updated_conditions.is_a? String
      if new_condition.is_a? String
        updated_conditions += " #{new_condition}"
      else
        updated_conditions = [updated_conditions += " #{new_condition.first}", 
                              *new_condition[1..-1]]
      end
    else
      if new_condition.is_a? String
        updated_conditions[0] += " #{new_condition}"
      else
        updated_conditions[0] += " #{new_condition[0]}"
        updated_conditions += new_condition[1..-1]
      end
    end
    updated_conditions
  end

  protected
  
  # TODO Remove this
  def get_user
    @user = self.current_user if logged_in?
  end

  def get_flickraw
    current_user ? FlickrPhoto.flickraw_for_user(current_user) : flickr
  end
  
  def flickr_required
    if logged_in? && current_user.flickr_identity
      true
    else
      redirect_to(:controller => 'flickr', :action => 'options')
    end
  end
  
  def photo_identities_required
    return true if logged_in? && !@photo_identities.blank?
    redirect_to(:controller => 'flickr', :action => 'options')
  end
  
  #
  # Filter method to require a curator for certain actions.
  #
  def curator_required
    unless logged_in? && current_user.is_curator?
      flash[:notice] = t(:only_curators_can_access_that_page)
      if session[:return_to] == request.fullpath
        redirect_to root_url
      else
        redirect_back_or_default(root_url)
      end
      return false
    end
  end
  
  # Override Devise implementation so we can set this for oauth2 / doorkeeper requests
  def current_user
    cu = super
    return cu unless cu.blank?
    return nil unless doorkeeper_token && doorkeeper_token.accessible?
    @current_user ||= User.find_by_id(doorkeeper_token.resource_owner_id)
  end
  
  #
  # Grab current user's time zone and set it as the default
  #
  def set_time_zone
    if logged_in?
      old_time_class = Chronic.time_class
      Time.use_zone(self.current_user.time_zone) do
        begin
          Chronic.time_class = Time.zone
          yield 
        ensure
          Chronic.time_class = old_time_class
        end
      end
    else
      yield
    end
  end
  
  def return_here_from_url
    return true if params[:return_to].blank?
    session[:return_to] = params[:return_to]
  end
  
  def user_logging
    return true unless logged_in?
    Rails.logger.info "  User: #{current_user.login} #{current_user.id}"
  end

  def user_request_logging
    msg = "Finished #{request.method} #{request.path} from #{request.ip}"
    msg += " for user: #{current_user.login} #{current_user.id}" if logged_in?
    Rails.logger.info msg
  end
  
  #
  # Return a 404 response with our default 404 page
  #
  def render_404
    unless request.format.json? || request.format.mobile?
      request.format = "html"
    end
    respond_to do |format|
      format.json { render json: { error: t(:not_found) }, status: 404 }
      format.all { render template: "errors/error_404", status: 404, layout: "application" }
    end
  end
  
  #
  # Redirect user to front page when they do something naughty.
  #
  def redirect_to_hell
    flash[:notice] = t(:you_tried_to_do_something_you_shouldnt)
    redirect_to root_path, :status => :see_other
  end

  # Caching
  # common place to put caching related code for simplier tuning
  def cache(time = 1.hour)
    expires_in(time)
  end
  
  def load_user_by_login
    @login = params[:login].to_s.downcase
    unless @selected_user = User.where("lower(login) = ?", @login).first
      return render_404
    end
  end

  def load_record(options = {})
    class_name = options.delete(:klass) || self.class.name.underscore.split('_')[0..-2].join('_').singularize
    class_name = class_name.to_s.underscore.camelcase
    klass = Object.const_get(class_name)
    record = klass.find(params[:id] || params["#{class_name}_id"]) rescue nil
    instance_variable_set "@#{class_name.underscore}", record
    render_404 unless record
  end

  def require_owner(options = {})
    class_name = options.delete(:klass) || self.class.name.underscore.split('_')[0..-2].join('_').singularize
    class_name = class_name.to_s.underscore.camelcase
    record = instance_variable_get("@#{class_name.underscore}")
    unless logged_in? && (current_user.id == record.user_id || current_user.is_admin?)
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_to record
        end
        format.json do
          return render :json => {:error => msg}
        end
      end
    end
  end

  def require_guide_user
    unless logged_in? && @guide.editable_by?(current_user)
      msg = t(:you_dont_have_permission_to_do_that)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          return redirect_to @guide
        end
        format.json do
          return render :json => {:error => msg}
        end
      end
    end
  end
  
  # Formerly used to address that ThinkingSphinx returns a maximum of
  # 50 pages. Now kept to keep the logic the same
  def limit_page_param_for_search
    if !params[:page].blank? && params[:page].to_i > 50
      render_404
    end
  end
  
  def search_for_places
    @q = params[:q].to_s.sanitize_encoding
    if params[:limit]
      @limit ||= params[:limit].to_i
      @limit = 50 if @limit > 50
    end
    site_place = @site.place if @site
    search_wheres = { match: { display_name: { query: @q, operator: "and" } } }
    if site_place
      search_wheres["ancestor_place_ids"] = site_place
    end
    search_params = {
      where: search_wheres,
      per_page: @limit, 
      page: params[:page]
    }
    if params[:with_geom].yesish?
      search_params.merge!(filters: [ { exists: { field: "geometry_geojson" } } ])
    elsif params[:with_geom].noish?
      search_params.merge!(filters: [ { 'not': { exists: { field: "geometry_geojson" } } } ])
    end
    @places = Place.elastic_paginate(search_params)
    Place.preload_associations(@places, :place_geometry_without_geom)
    if logged_in? && @places.blank?
      if ydn_places = GeoPlanet::Place.search(params[:q], :count => 5)
        new_places = ydn_places.map {|p| Place.import_by_woeid(p.woeid)}.compact
        @places = Place.where("id in (?)", new_places.map(&:id).compact).page(1).to_a
      end
    end
  end
  
  def catch_missing_mobile_templates
    begin
      yield
    rescue ActionView::MissingTemplate => e
      if in_mobile_view?
        flash[:notice] = t(:no_mobilized_version_of_that_view)
        session[:mobile_view] = false
        Rails.logger.debug "[DEBUG] Caught missing mobile template: #{e}: \n#{e.backtrace.join("\n")}"
        return redirect_to request.path.gsub(/\.mobile/, '')
      end
      raise e
    end
    true
  end
  
  def mobilized
    @mobilized = true
  end
  
  def unmobilized
    @mobilized = false
    request.format = :html if in_mobile_view? && request.format == :mobile
  end
  
  # Get current_user's preferences, prefs in the session, or stash new prefs in the session
  def current_preferences(update_params = nil)
    update_params ||= params[:preferences]
    prefs = if logged_in?
      current_user.preferences
    else
      session[:preferences] ||= User.preference_definitions.inject({}) do |memo, pair|
        name, pref = pair
        memo[name] = pref.default_value
        memo
      end
    end
    
    update_params = update_params.reject{|k,v| v.blank?} if update_params
    if update_params.is_a?(Hash) && !update_params.empty?
      # prefs.update_attributes(update_params)
      if logged_in?
        update_params.each do |k,v|
          new_value = if v == "true"
            true
          elsif v == "false"
            false
          elsif v.to_i > 0
            v.to_i
          else
            v
          end
          current_user.write_preference(k, new_value) unless new_value.blank?
        end
      else
        prefs.update(update_params)
      end
    end
    
    if logged_in?
      current_user.save if current_user.preferences_changed?
      current_user.preferences
    else
      session[:preferences] = prefs
    end
  end
  
  def log_timer
    starttime = Time.now
    Rails.logger.debug "\n\n[DEBUG] LOG TIMER START #{starttime}"
    yield
    endtime = Time.now
    Rails.logger.debug "\n\n[DEBUG] LOG TIMER END #{endtime} (#{endtime - starttime} s)\n\n"
  end

  def require_admin_or_trusted_project_manager_for(project)
    allowed_project_roles = %w(manager admin)
    return true if current_user.has_role?(:admin) if logged_in?
    project_user = project.project_users.where(:user_id => current_user).first if logged_in?
    if !project_user || 
        !project.trusted? || 
        !allowed_project_roles.include?(project_user.role)
      message = t(:you_must_be_a_member_of_this_project_to_do_that)
      respond_to do |format|
        format.html do
          flash[:notice] = message
          redirect_back_or_default project_url(project)
        end
        format.json do
          render :json => {:error => message}, :status => :unprocessable_entity
        end
      end
    end
  end

  def limited_per_page
    requested_per_page = params[:per_page].to_i
    if requested_per_page > 200
      200
    elsif requested_per_page <= 0
      30
    else
      requested_per_page
    end
  end

  def json_request?
    request.format.json?
  end

  private

  def admin_required
    unless logged_in? && current_user.has_role?(:admin)
      msg = t(:only_administrators_may_access_that_page)
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to observations_path
        end
        format.js do
          render :status => :unprocessable_entity, :text => msg
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:error => msg}
        end
      end
      return false
    end
  end

  def remove_header_and_footer_for_apps
    return true unless is_android_app? || is_iphone_app?
    @headless = true
    @footless = true
    true
  end
  
  # http://blog.serendeputy.com/posts/how-to-prevent-browsers-from-caching-a-page-in-rails/
  def prevent_caching
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  end
  
  # try to log a user in through a 3rd party auth provider based on a GET param
  # if they're already logged in, strip out the param
  def login_from_param
    return true unless params[:auth_provider]
    return true unless request.get?
    if logged_in?
      uri_pieces = request.fullpath.split('?')
      param_pieces = uri_pieces[1].split('&')
      param_pieces.delete_if {|p| p =~ /^auth_provider/}
      redirect_to [uri_pieces[0], param_pieces.join('&')].join('?')
      return true
    end
    provider, url = ProviderAuthorization::AUTH_URLS.detect do |provider, url| 
      provider.downcase == params[:auth_provider].to_s.downcase
    end
    redirect_to url if url
    true
  end

  # When a user tries to load a page that requires login, we assume they want
  # to land there after signing up. See RegistrationsController for the
  # redirect.
  def authenticate_user!(*args)
    if request.get? && !logged_in?
      session[:return_to_for_new_user] = request.fullpath
    end
    super
  end

  def authenticate_with_oauth?
    return false if !session.blank? && !session['warden.user.user.key'].blank?
    return false if request.authorization.to_s =~ /^Basic /
    return false unless !params[:access_token].blank? || request.authorization.to_s =~ /^Bearer /
    @doorkeeper_for_called = true
  end

  def authenticated_with_oauth?
    @doorkeeper_for_called && doorkeeper_token && doorkeeper_token.accessible?
  end

  def pagination_headers_for(collection)
    return unless collection.respond_to?(:total_entries)
    response.headers['X-Total-Entries'] = collection.total_entries.to_s
    response.headers['X-Page'] = collection.current_page.to_s
    response.headers['X-Per-Page'] = collection.per_page.to_s
  end

  # Encapsulates common pattern for actions that start a bg task get called 
  # repeatedly to check progress
  # Key is required, and a block that assigns a new Delayed::Job to @job
  def delayed_progress(key)
    @tries = params[:tries].to_i
    if @tries > 20
      @status = "error"
      @error_msg = t(:this_is_taking_forever)
      return
    # elsif @tries > 0
    else
      @job_id = Rails.cache.read(key)
      @job = Delayed::Job.find_by_id(@job_id)
    end
    if @job_id
      if @job && @job.last_error
        @status = "error"
        @error_msg = if current_user.is_admin?
          @job.last_error
        else
          t(:this_job_failed_to_run, :email => CONFIG.help_email)
        end
      elsif @job
        @status = "working"
      else
        @status = "done"
        Rails.cache.delete(key)
      end
    else
      @status = "start"
      yield
      Rails.cache.write(key, @job.id)
    end
  end

  def whitelist_params
    params.permit!
  end

  # Coerce the format unless in preselected list. Rescues from ActionView::MissingTemplate
  def self.accept_formats(*args)
    options = args.last.is_a?(Hash) ? args.last : {}
    default = options[:default] ? options[:default].to_sym : :html
    formats = [args].flatten.map(&:to_sym)
    before_filter(options) do
      request.format = default if request.format.blank? || !formats.include?(request.format.to_sym)
    end
  end

  def allow_external_iframes
    response.headers["X-Frame-Options"] = "ALLOWALL"
  end

  # adding extra info to the payload sent to ActiveSupport::Notifications
  # used in metrics collecting libraries like the Logstasher
  def append_info_to_payload(payload)
    super
    payload.merge!(Logstasher.payload_from_request( request ))
    payload.merge!(Logstasher.payload_from_session( session ))
    if logged_in?
      payload.merge!(Logstasher.payload_from_user( current_user ))
    end
  end
end

# Override the Google Analytics insertion code so it won't track admins
module Rubaidh # :nodoc:
  module GoogleAnalyticsMixin
    # An after_filter to automatically add the analytics code.
    def add_google_analytics_code
      return if logged_in? && current_user.has_role?(User::JEDI_MASTER_ROLE)
      
      code = google_analytics_code
      return if code.blank?
      response.body.gsub! '</body>', code + '</body>' if response.body.respond_to?(:gsub!)
    end
  end
end

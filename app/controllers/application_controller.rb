# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  include Ambidextrous
  include Shared::FiltersModule

  # many people try random URLs like wordpress login pages with format .php
  # for any format we do not recognize, make sure we render a proper 404
  rescue_from ActionController::UnknownFormat, with: :render_404

  helper :all # include all helpers, all the time
  protect_from_forgery with: :exception, if: -> { request.headers["Authorization"].blank? }
  before_action :permit_params
  around_action :set_time_zone
  around_action :logstash_catchall
  before_action :return_here, :only => [:index, :show, :by_login]
  before_action :return_here_from_url
  before_action :preload_user_preferences
  before_action :user_logging
  before_action :check_user_last_active
  after_action :user_request_logging
  before_action :remove_header_and_footer_for_apps
  before_action :login_from_param
  before_action :set_site
  before_action :draft_site_requires_login
  before_action :draft_site_requires_admin
  before_action :set_ga_trackers
  before_action :set_request_locale
  before_action :check_preferred_place
  before_action :check_preferred_site
  before_action :sign_out_spammers
  before_action :set_session_oauth_application_id

  # /ping should skip all before filters and just render
  skip_before_action *_process_action_callbacks.map(&:filter), only: :ping, raise: false

  PER_PAGES = [10,30,50,100,200]
  HEADER_VERSION = 21
  
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

  def ping
    render json: { status: "available" }
  end

  private

  # Store the URI of the current request in the session.
  #
  # We can return to this location by calling #redirect_back_or_default.
  def store_location
    session[:return_to] = request.fullpath
  end

  def draft_site_requires_login
    return unless @site && @site.draft?
    return if [ login_path, user_session_path, session_path ].include?( request.path )
    doorkeeper_authorize! if authenticate_with_oauth?
    authenticate_user! unless ( authenticated_with_oauth? || logged_in? )
  end

  def draft_site_requires_admin
    return unless @site && @site.draft?
    return if [ login_path, user_session_path, session_path ].include?( request.path )
    return redirect_to login_path if !current_user
    unless current_user.is_admin? ||
        ( @site && @site.site_admins.where( user_id: current_user ).first )
      sign_out current_user
      flash[:error] = t(:only_administrators_may_access_that_page)
      redirect_to login_path
    end
  end

  def set_ga_trackers
    return true unless request.format.blank? || request.format.html?
    return true if request.env["HTTP_DNT"] == "1"
    return true if current_user && current_user.prefers_no_tracking?
    trackers = [ ]
    if Site.default && !Site.default.google_analytics_tracker_id.blank?
      trackers << [ "default", Site.default.google_analytics_tracker_id ]
    end
    if @site && @site != Site.default && !@site.google_analytics_tracker_id.blank?
      trackers << [ @site.name.gsub(/\s+/, '').underscore, @site.google_analytics_tracker_id ]
    end
    request.env[ "inat_ga_trackers" ] = trackers unless trackers.blank?
  end

  def check_preferred_place
    return true unless current_user
    if current_user.prefers_no_place?
      session.delete(:potential_place)
      return true
    end
    return true unless session[:potential_place].blank?
    if current_user.latitude && current_user.longitude && current_user.place.blank?
      potential_place = Place.
        containing_lat_lng( current_user.latitude, current_user.longitude ).
        where( admin_level: Place::COUNTRY_LEVEL ).first
      if potential_place
        place_name = potential_place.translated_name
        session[:potential_place] = {
          id: potential_place.id,
          name: place_name == "United States" ? "the United States" : place_name
        }
      end
    end
    true
  end

  def check_preferred_site
    return true unless flash.empty?
    return true unless current_user
    if current_user.prefers_no_site?
      session.delete(:potential_site)
      return true
    end
    return true unless session[:potential_place].blank?
    if params[:test].to_s =~ /network/
      session.delete(:potential_site)
      n, lat, lon = params[:test].split( "|" )
      if lat && lon
        current_user.latitude = lat.to_f
        current_user.longitude = lon.to_f
      end
    end
    viewing_non_default_site = @site != Site.default
    viewer_affiliated_with_non_default_site = (
      !current_user.site.blank? && current_user.site != Site.default
    )
    if viewing_non_default_site || viewer_affiliated_with_non_default_site
      session.delete(:potential_site)
      return true
    end
    if current_user.latitude && current_user.longitude
      potential_place = Place.
        containing_lat_lng( current_user.latitude, current_user.longitude ).
        where( "places.id IN (?)", Site.where( "NOT draft" ).pluck(:place_id).compact ).first
      unless potential_place
        session.delete(:potential_site)
        return true
      end
      potential_site = Site.where( "NOT draft" ).where( place_id: potential_place.id ).first
      if potential_site && potential_site != current_user.site
        session[:potential_site] = {
          id: potential_site.id,
          name: potential_site.name,
          place_name: potential_place.translated_name
        }
      else
        session.delete(:potential_site)
      end
    end
    true
  end

  def sign_out_spammers
    if current_user && current_user.spammer?
      sign_out current_user
    end
  end

  # Redirect to the URI stored by the most recent store_location call or
  # to the passed default.  Set an appropriately modified
  #   after_action :store_location, :only => [:index, :new, :show, :edit]
  # for any controller you want to be bounce-backable.
  def redirect_back_or_default(default)
    back_url = session[:return_to] # || request.env['HTTP_REFERER']
    if back_url && ![request.path, request.url].include?(back_url)
      redirect_to back_url, :status => :see_other
    else
      redirect_to default, :status => :see_other
    end
    session[:return_to] = nil
  rescue ActionController::RedirectBackError
    redirect_to default, :status => :see_other
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

  def load_registration_form_data
    @footless = true
    @no_footer_gap = true
    @responsive = true
    @observations = @site.login_featured_observations
  end

  def get_flickraw
    current_user ? FlickrPhoto.flickraw_for_user(current_user) : flickr
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
      begin
        Time.use_zone( self.current_user.time_zone ) do
          Chronic.time_class = Time.zone
          yield
        end
      ensure
        Chronic.time_class = old_time_class
      end
    else
      yield
    end
  end

  def logstash_catchall
    begin
      yield
    ensure
      if status == 422
        # Logstasher uses ActiveSupport::Notifications to write controller action
        # logs, but it won't have access to the response there. This ensures
        # that all requests with response status 422 get an additional log entry
        # with the response body
        Logstasher.write_unprocessable( request, response, session, current_user )
      end
    end
  end

  #
  # if Makara is configured with replica DBs, querying of replicas is currently
  # disabled by default. Actions must use this in a `prepend_around_action` to
  # have any queries run against the replicas. e.g.
  #
  #    prepend_around_action :enable_replica
  #
  def enable_replica
    begin
      ActiveRecord::Base.connection.enable_replica
      yield
    ensure
      ActiveRecord::Base.connection.disable_replica
    end
  end

  def return_here_from_url
    return true if params[:return_to].blank?
    session[:return_to] = params[:return_to]
  end

  def preload_user_preferences
    if logged_in?
      User.preload_associations(current_user, :stored_preferences)
    end
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

  def check_user_last_active
    if current_user
      # there is a current_user, so that user is active
      if current_user.last_active.nil? || current_user.last_active != Date.today
        current_user.last_active = Date.today
        current_user.last_ip = Logstasher.ip_from_request_env( request.env )
        current_user.save
      end
      # since they are active, unsuspend any stopped subscriptions
      if current_user.subscriptions_suspended_at
        current_user.update_column(:subscriptions_suspended_at, nil)
      end
    end
  end

  #
  # Return a 404 response with our default 404 page
  #
  def render_404
    unless request.format.json?
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
    flash[:notice] = t(:you_dont_have_permission_to_do_that)
    redirect_to root_path, status: :see_other
  end

  # Caching
  # common place to put caching related code for simplier tuning
  def cache(time = 1.hour)
    expires_in(time)
  end
  
  def load_user_by_login
    @login = params[:login].to_s.downcase
    @selected_user =  @login.blank? ? nil :
      User.where("lower(login) = ?", @login).take
    return render_404 unless @selected_user
  end

  def load_record(options = {})
    if options[:klass].is_a?(Class)
      klass = options[:klass]
      class_name = klass.name.split('::').last
    else
      class_name = options.delete(:klass) || self.class.name.underscore.split('_')[0..-2].join('_').singularize
      class_name = class_name.to_s.underscore.camelcase
      klass = Object.const_get(class_name)
    end
    record_id = params[options[:param]] || params[:id] || params["#{class_name}_id"]
    if klass.respond_to?(:find_by_uuid)
      record = klass.find_by_uuid( record_id )
    end
    record ||= klass.find( record_id ) rescue nil
    instance_variable_set "@#{class_name.underscore}", record
    return render_404 unless record

    record
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
          return render json: { error: msg }, status: :forbidden
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
          return render json: { error: msg }, status: :forbidden
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
    
    update_params = update_params.to_h.reject{|k,v| v.blank?} if update_params
    if update_params.is_a?(Hash) && !update_params.empty?
      # prefs.update(update_params)
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
    unless logged_in? && current_user.is_admin?
      only_admins_failure_state
    end
  end

  def admin_or_this_site_admin_required
    unless logged_in? && ( current_user.is_admin? || ( @site && current_user.is_site_admin_of?( @site ) ) )
      only_admins_failure_state
    end
  end

  def admin_or_any_site_admin_required
    unless logged_in? && ( current_user.is_admin? || current_user.site_admins.any? )
      only_admins_failure_state
    end
  end

  def only_admins_failure_state
    msg = t(:only_administrators_may_access_that_page)
    respond_to do |format|
      format.html do
        flash[:error] = msg
        redirect_back_or_default( root_url )
      end
      format.js do
        render :status => :unprocessable_entity, :plain => msg
      end
      format.json do
        render :status => :unprocessable_entity, :json => {:error => msg}
      end
    end
    throw :abort
  end

  def site_admin_required
    return true if logged_in? && current_user.has_role?(:admin)
    return true if logged_in? && @site && @site.site_admins.detect{|sa| sa.user_id == current_user.id}
    msg = t(:only_administrators_may_access_that_page)
    respond_to do |format|
      format.html do
        flash[:error] = msg
        redirect_to observations_path
      end
      format.js do
        render status: :unprocessable_entity, plain: msg
      end
      format.json do
        render status: :unprocessable_entity, json: { error: msg }
      end
    end
    throw :abort
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
    if url
      return redirect_to oauth_bounce_url( provider: provider )
    end
    true
  end

  # When a user tries to load a page that requires login, we assume they want
  # to land there after signing up. See RegistrationsController for the
  # redirect.
  def authenticate_user!(*args)
    if request.get? && !logged_in?
      session[:return_to] = request.fullpath
      session[:return_to_for_new_user] = request.fullpath
    end
    super
  end

  def authenticate_with_oauth?
    # Don't want OAuth if we're already authenticated
    return false if !session.blank? && !session['warden.user.user.key'].blank?
    # Need an access token for OAuth
    return false unless !params[:access_token].blank? || request.authorization.to_s =~ /^Bearer /
    # If the bearer token is a JWT with a user we don't want to go through
    # Doorkeeper's OAuth-based flow
    token = request.authorization.to_s.split( /\s+/ ).last
    jwt_claims = begin
      ::JsonWebToken.decode( token )
    rescue JWT::DecodeError => e
      nil
    end
    return false if jwt_claims && jwt_claims.fetch( "user_id" )
    @should_authenticate_with_oauth = true
  end

  def authenticated_with_oauth?
    @should_authenticate_with_oauth && doorkeeper_token && doorkeeper_token.accessible?
  end

  def authenticated_with_jwt?
    return false unless current_user
    return false unless ( token = request.authorization.to_s.split( /\s+/ ).last )

    jwt_claims = begin
      ::JsonWebToken.decode( token )
    rescue JWT::DecodeError
      nil
    end
    return false unless jwt_claims && ( current_user.id == jwt_claims.fetch( "user_id" ) )

    true
  end

  def pagination_headers_for(collection)
    return unless collection.respond_to?(:total_entries)
    response.headers['X-Total-Entries'] = collection.total_entries.to_s
    response.headers['X-Page'] = collection.current_page.to_s
    response.headers['X-Per-Page'] = collection.per_page.to_s
  end

  def set_session_oauth_application_id
    if doorkeeper_token && doorkeeper_token.accessible? && (a = doorkeeper_token.try(:application))
      session["oauth_application_id"] = a.id
    elsif ( auth_header = request.headers["Authorization"] ) && ( token = auth_header.split(" ").last )
      jwt_claims = begin
        ::JsonWebToken.decode(token)
      rescue JWT::DecodeError => e
        nil
      end
      if jwt_claims && ( oauth_application_id = jwt_claims["oauth_application_id"] )
        session["oauth_application_id"] = oauth_application_id
      end
    end
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
          t(:this_job_failed_to_run, email: @site.email_help)
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

  def permit_params
    params.permit!
  end

  # Coerce the format unless in preselected list. Rescues from ActionView::MissingTemplate
  def self.accept_formats(*args)
    options = args.last.is_a?(Hash) ? args.last : {}
    default = options[:default] ? options[:default].to_sym : :html
    formats = [args].flatten.map(&:to_sym)
    before_action(options) do
      request.format = default if request.format.blank? || !formats.include?(request.format.to_sym)
    end
  end

  def self.allow_external_iframes( options )
    # modify the content security policy for the actions specified in options to
    # disable the frame_ancestors policy, thus allowing iframes to request these actions
    content_security_policy( **options ) do |p|
      p.frame_ancestors nil
    end
    before_action( options ) do
      response.headers["X-Frame-Options"] = "ALLOWALL"
    end
  end

  def allow_cors
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = %w{GET POST PUT DELETE}.join(",")
    headers["Access-Control-Allow-Headers"] =
      %w{Origin Accept Content-Type X-Requested-With X-CSRF-Token}.join(",")
    head(:ok) if request.request_method == "OPTIONS"
  end

  # NOTE: this is called as part of ActionController::Instrumentation, and not
  # referenced elsewhere within this codebase. The payload data will be used
  # by config/initializers/logstasher.rb
  #
  # adding extra info to the payload sent to ActiveSupport::Notifications
  # used in metrics collecting libraries like the Logstasher
  def append_info_to_payload(payload)
    super
    payload.merge!(Logstasher.payload_from_request( request ))
    payload.merge!( { session: session } )
    if logged_in?
      payload.merge!(Logstasher.payload_from_user( current_user ))
    end
  end

  def user_viewed_updates_for( record, options = {} )
    return unless logged_in?
    updates = UpdateAction.where( resource: record )
    if options[:delay]
      ActiveRecord::Base.connection.without_sticking do
        UpdateAction.delay( priority: USER_PRIORITY ).user_viewed_updates( updates, current_user.id )
      end
    else
      UpdateAction.user_viewed_updates( updates, current_user.id )
    end
  end

  def blocked_by_content_freeze
    if CONFIG.content_freeze_enabled
      render template: "content_freeze", status: 403, layout: "application"
    end
  end

end

# Override the Google Analytics insertion code so it won't track admins
module Rubaidh # :nodoc:
  module GoogleAnalyticsMixin
    # An after_action to automatically add the analytics code.
    def add_google_analytics_code
      return if logged_in? && current_user.has_role?(User::JEDI_MASTER_ROLE)
      
      code = google_analytics_code
      return if code.blank?
      response.body.gsub! '</body>', code + '</body>' if response.body.respond_to?(:gsub!)
    end
  end
end

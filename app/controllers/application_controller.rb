# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  include AuthenticatedSystem
  include RoleRequirementSystem
  include Ambidextrous
  
  has_mobile_fu
  around_filter :catch_missing_mobile_templates
  
  helper :all # include all helpers, all the time
  protect_from_forgery
  filter_parameter_logging :password, :password_confirmation
  before_filter :login_from_cookie, :get_user, :set_time_zone
  before_filter :return_here, :only => [:index, :show, :by_login]
  before_filter :return_here_from_url
  before_filter :user_logging
  before_filter :remove_header_and_footer_for_apps
  before_filter :login_from_param
  
  PER_PAGES = [10,30,50,100]
  
  private
  
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
  
  def get_net_flickr
    Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
  end

  def get_flickraw
    FlickRaw.api_key = FLICKR_API_KEY
    FlickRaw.shared_secret = FLICKR_SHARED_SECRET
    flickr
  end
  
  def flickr_required
    if logged_in? && current_user.flickr_identity
      true
    else
      redirect_to(:controller => 'flickr', :action => 'link')
    end
  end
  
  def photo_identities_required
    return true if logged_in? && !@photo_identities.blank?
    redirect_to(:controller => 'flickr', :action => 'link')
  end
  
  #
  # Filter method to require a curator for certain actions.
  #
  def curator_required
    unless logged_in? && current_user.is_curator?
      flash[:notice] = "Only curators can access that page."
      if session[:return_to] == request.request_uri
        redirect_to root_url
      else
        redirect_back_or_default(root_url)
      end
      return false
    end
  end
  

  
  #
  # Grab current user's time zone and set it as the default
  #
  def set_time_zone
    Time.zone = self.current_user.time_zone if logged_in?
    Chronic.time_class = Time.zone
  end
  
  #
  # Filter to set a return url
  #
  def return_here
    ie_needs_return_to = false
    if request.user_agent =~ /msie/i && params[:format].blank? && 
        ![Mime::JS, Mime::JSON, Mime::XML, Mime::KML, Mime::ATOM].map(&:to_s).include?(request.format.to_s)
      ie_needs_return_to = true
    end
    if (ie_needs_return_to || request.format.html?) && !params.keys.include?('partial')
      session[:return_to] = request.request_uri
    end
    true
  end
  
  def return_here_from_url
    return true if params[:return_to].blank?
    session[:return_to] = params[:return_to]
  end
  
  def user_logging
    return true unless logged_in?
    Rails.logger.info "  User: #{current_user.login} #{current_user.id}"
  end
  
  #
  # Return a 404 response with our default 404 page
  #
  def render_404
    return render(:file => "#{RAILS_ROOT}/public/404.html", :status => 404)
  end
  
  #
  # Redirect user to front page when they do something naughty.
  #
  def redirect_to_hell
    flash[:notice] = "You tried to do something you shouldn't, like edit " + 
      "someone else's data without permission.  Don't be evil."
    redirect_to root_path
  end
  
  # Caching
  # common place to put caching related code for simplier tuning
  def cache(time = 1.hour)
    expires_in(time)
  end
  
  def load_user_by_login
    @login = params[:login].to_s.downcase
    unless @selected_user = User.first(:conditions => ["lower(login) = ?", @login])
      return render_404
    end
  end
  
  # ThinkingSphinx returns a maximum of 50 pages. Anything higher than 
  # that, we want to 404 to avoid a TS error. 
  def limit_page_param_for_thinking_sphinx
    if !params[:page].blank? && params[:page].to_i > 50 
      render_404 
    end 
  end
  
  def search_for_places
    @q = params[:q]
    if params[:limit]
      @limit ||= params[:limit].to_i
      @limit = 50 if @limit > 50
    end
    @places = Place.search(@q, :page => params[:page], :limit => @limit)
    if logged_in? && @places.blank?
      if ydn_places = GeoPlanet::Place.search(params[:q], :count => 5)
        new_places = ydn_places.map {|p| Place.import_by_woeid(p.woeid)}
        @places = Place.paginate(new_places.map(&:id).compact, :page => 1)
      end
    end
    @places.compact!
  end
  
  def catch_missing_mobile_templates
    begin
      yield
    rescue ActionView::MissingTemplate => e
      if in_mobile_view?
        flash[:notice] = "No mobilized version of that view."
        session[:mobile_view] = false
        logger.debug "[DEBUG] Caught missing mobile template: #{e}: \n#{e.backtrace.join("\n")}"
        return redirect_to request.path
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
      current_user.save
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
  
  private
  
  def admin_required
    unless logged_in? && current_user.has_role?(:admin)
      flash[:notice] = "Only Administrators may access that page"
      redirect_to observations_path
    end
  end
  
  def sanitize_sphinx_query(q)
    q.gsub(/[^\w\s\.\'\-]+/, '').gsub(/\-/, '\-')
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
      uri_pieces = request.request_uri.split('?')
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
end

# Override the Google Analytics insertion code so it won't track admins
module Rubaidh # :nodoc:
  module GoogleAnalyticsMixin
    # An after_filter to automatically add the analytics code.
    def add_google_analytics_code
      return if logged_in? && current_user.has_role?(User::JEDI_MASTER_ROLE)
      
      code = google_analytics_code(request)
      return if code.blank?
      response.body.gsub! '</body>', code + '</body>' if response.body.respond_to?(:gsub!)
    end
  end
end

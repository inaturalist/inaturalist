# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  include AuthenticatedSystem
  include RoleRequirementSystem
  
  helper :all # include all helpers, all the time
  protect_from_forgery
  filter_parameter_logging :password, :password_confirmation
  before_filter :login_from_cookie, :get_user, :set_time_zone
  before_filter :return_here, :only => [:index, :show, :by_login]

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
  
  #
  # Filter method to require a curator for certain actions.
  #
  def curator_required
    unless logged_in? && current_user.is_curator?
      flash[:notice] = "Only curators can access that page."
      redirect_to session[:return_to] || root_url
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
    if request.format == Mime::HTML && !params.keys.include?('partial')
      session[:return_to] = request.request_uri
    end
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
    @login = params[:login]
    unless @selected_user = User.find_by_login(@login)
      return render_404
    end
  end
  
  # ThinkingSphinx returns a maximum of 50 pages. Anything higher than 
  # that, we want to 404 to avoid a TS error. 
  def limit_page_param_for_thinking_sphinx
    if params[:page] && params[:page].to_i > 50 
      render_404 
    end 
  end
  
  def search_for_places
    @q = params[:q]
    @places = Place.search(@q, :page => params[:page])
    if logged_in? && (@places.blank? || @places.compact.map(&:display_name).join(' ').downcase !~ /#{@q}/)
      if ydn_places = GeoPlanet::Place.search(params[:q], :count => 5)
        new_places = ydn_places.map {|p| Place.import_by_woeid(p.woeid)}
        @places = Place.paginate(new_places.map(&:id).compact, :page => 1)
      end
    end
    @places.compact!
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

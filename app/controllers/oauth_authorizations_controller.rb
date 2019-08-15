class OauthAuthorizationsController < Doorkeeper::AuthorizationsController
  include Ambidextrous
  include Shared::FiltersModule
  layout "bootstrap"
  prepend_before_filter :return_here, :only => [:new]
  prepend_before_filter :set_request_locale, :set_site

  private
  def return_here
    @responsive = true
    @footless = true
    ie_needs_return_to = false
    if request.user_agent =~ /msie/i && params[:format].blank? && 
        ![Mime::JS, Mime::JSON, Mime::XML, Mime::KML, Mime::ATOM].map(&:to_s).include?(request.format.to_s)
      ie_needs_return_to = true
    end
    if (ie_needs_return_to || request.format.blank? || request.format.html?) && !params.keys.include?('partial')
      session[:return_to] = request.fullpath
    end
    true
  end
end

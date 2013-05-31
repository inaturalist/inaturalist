class OauthAuthorizationsController < Doorkeeper::AuthorizationsController
  include Ambidextrous
  prepend_before_filter :return_here, :only => [:new]

  private
  def return_here
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
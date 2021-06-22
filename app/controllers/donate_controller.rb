class DonateController < ApplicationController
  layout "bootstrap"
  before_filter do
    @responsive = true
    @footless = true
    @no_footer_gap = true
    @shareable_image_url = FakeView.image_url( "donate-banner.png" )
  end

  def index
    if new_params = redirect_params
      return redirect_to donate_url( new_params )
    end
  end

  def monthly_supporters
    if new_params = redirect_params
      return redirect_to monthly_supporters_url( new_params )
    end
  end

  private

  def redirect_params
    if Site.default && @site && @site.id != Site.default.id
      new_params = {
        host: Site.default.domain,
        utm_source: @site.name
      }.merge( request.query_parameters.reject{|k,v| k.to_s == "inat_site_id" } )
      new_params
    elsif params[:utm_source].blank?
      # We're doing this because the donorbox iframe only seems to derive utm
      # params from the URL of the parent window, and will ignore them all if
      # utm_source isn't set
      new_params = {
        host: Site.default.domain,
        utm_source: Site.default.name,
        utm_medium: "web"
      }.merge( request.query_parameters.reject{|k,v| k.to_s == "inat_site_id" } )
      new_params
    end
  end

end

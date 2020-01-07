class DonateController < ApplicationController
  layout "bootstrap"
  before_filter do
    @responsive = true
    @footless = true
    @no_footer_gap = true
    @shareable_image_url = FakeView.image_url( "donate-banner.png" )
    if Site.default && @site && @site.id != Site.default.id
      new_params = {
        host: Site.default.domain,
        utm_source: @site.name
      }.merge( request.query_parameters.reject{|k,v| k.to_s == "inat_site_id" } )
      url = donate_url( new_params )
      redirect_to( url )
    end
  end

  def index
  end

  def monthly_supporters
  end

end

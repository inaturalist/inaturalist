class DonateController < ApplicationController
  layout "bootstrap"
  before_filter do
    @responsive = true
    @footless = true
    @no_footer_gap = true
  end

  def index
    if Site.default && @site && @site.id != Site.default.id
      return redirect_to donate_url( host: Site.default.domain )
    end
  end
end

class DonateController < ApplicationController
  layout "bootstrap"
  before_filter do
    @responsive = true
    @footless = true
    @no_footer_gap = true
  end
end

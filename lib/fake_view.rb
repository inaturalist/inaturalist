# Sometimes it's just useful to have access to view helpers outside of views,
# even if it makes you feel dirty.
class FakeView < ActionView::Base
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::UrlHelper
  # include ActionController::UrlWriter
  include Rails.application.routes.url_helpers
  include ApplicationHelper
  include PlacesHelper
  include TaxaHelper
  include GuidesHelper
  include ObservationsHelper

  @@default_url_options = {
    host: Site.default ? Site.default.url.sub( "http://", '' ) : "http://localhost"
  }
  
  def method_missing(method, *args)
    # hack around those pesky protected url methods
    if method.to_s =~ /url$/ && respond_to?(method)
      send(method, *args)
    else
      super
    end
  end

  def initialize(options = {})
    super
    self.view_paths = [File.join(Rails.root, 'app/views'), options[:view_paths]].flatten.compact
  end
  
  def self.method_missing(method, *args)
    @@fake_view ||= self.new
    @@fake_view.send(method, *args)
  end

  def self.default_url_options
    @@default_url_options
  end

  def config
    fake_controller.config
  end

  def fake_controller
    @fake_controller ||= ApplicationController.new
  end

  def params
    {}
  end
end

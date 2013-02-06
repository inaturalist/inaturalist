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

  @@default_url_options = {:host => CONFIG.site_url.sub("http://", '')}
  
  def method_missing(method, *args)
    # hack around those pesky protected url methods
    if method.to_s =~ /url$/ && respond_to?(method)
      send(method, *args)
    else
      super
    end
  end

  def initialize
    super
    self.view_paths = [File.join(Rails.root, 'app/views')]
  end
  
  def self.method_missing(method, *args)
    @@fake_view ||= self.new
    @@fake_view.send(method, *args)
  end

  def self.default_url_options
    @@default_url_options
  end
end

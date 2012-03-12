# Sometimes it's just useful to have access to view helpers outside of views,
# even if it makes you feel dirty.
class FakeView < ActionView::Base
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::UrlHelper
  include ActionController::UrlWriter
  include ApplicationHelper

  @@default_url_options = {:host => APP_CONFIG[:site_url].sub("http://", '')}

  def initialize
    super
    self.view_paths = [File.join(RAILS_ROOT, 'app/views')]
  end
end
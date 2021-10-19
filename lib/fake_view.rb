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
  include UsersHelper

  @@default_url_options = {
    host: Site.default ? Site.default.url.sub( "http://", '' ) : "http://localhost",
    port: Site.default && URI.parse( Site.default.url ).port != 80 ? URI.parse( Site.default.url ).port : nil
  }
  
  def method_missing(method, *args)
    # hack around those pesky protected url methods
    if method.to_s =~ /url$/ && respond_to?(method)
      send(method, *args)
    else
      super
    end
  # TODO Rails6: fix FakeView and remove this rescue
  rescue NoMethodError => e
    Rails.logger.error "[ERROR]"
    Rails.logger.error "[ERROR] FakeView is broken and needs fixin': #{e}"
    Rails.logger.error "[ERROR]"
  end

  def initialize( options = {} )
    view_paths = [File.join( Rails.root, "app/views" ), options[:view_paths]].flatten.compact
    lookup_context = lookup_context || options[:lookup_context] || ActionView::LookupContext.new( view_paths )
    assigns = options[:assigns] || {}
    super( lookup_context, assigns, fake_controller )
  end
  
  def self.method_missing(method, *args)
    @@fake_view ||= self.new
    @@fake_view.send(method, *args)
  # TODO Rails6: fix FakeView and remove this rescue
  rescue NoMethodError => e
    Rails.logger.error "[ERROR]"
    Rails.logger.error "[ERROR] FakeView is broken and needs fixin': #{e}"
    Rails.logger.error "[ERROR]"
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

  # Overriding this so that assets we have chosen not to be used with a digest
  # don't actually use a digest
  def asset_path( source, options = {} )
    if source !~/^http/ && source =~ /#{NonStupidDigestAssets.whitelist.join( "|" )}/
      return "/assets/#{source}"
    end
    super( source, options )
  end
end

# frozen_string_literal: true

class UrlHelper
  include Singleton
  include Rails.application.routes.url_helpers

  class << self
    def method_missing( ... )
      UrlHelper.instance.send( ... )
    end

    def respond_to_missing?( method, include_private = false )
      UrlHelper.instance.respond_to? method, include_private
    end
  end

  def default_url_options
    @default_url_options ||= {
      host: Site.default ? Site.default.url.sub( "http://", "" ) : "http://localhost",
      port: Site.default && URI.parse( Site.default.url ).port != 80 ? URI.parse( Site.default.url ).port : nil,
      protocol: URI.parse( Site.default.url ).scheme
    }
  end
end

# frozen_string_literal: true

#
# Allows access to rendering, helpers, and URL helpers from anywhere. Works by
# including URL helpers and delegating other methods to ApplicationController
#
class FakeView
  include Rails.application.routes.url_helpers

  def initialize( options = {} )
    super()
    return unless options[:view_paths]

    controller.view_paths += options[:view_paths]
  end

  def default_url_options
    @default_url_options ||= {
      host: Site.default ? Site.default.url.sub( "http://", "" ) : "http://localhost",
      port: Site.default && URI.parse( Site.default.url ).port != 80 ? URI.parse( Site.default.url ).port : nil,
      protocol: URI.parse( Site.default.url ).scheme
    }
  end

  def self.fake_instance
    @fake_instance ||= new
  end

  def self.method_missing( method, *args )
    fake_instance.send( method, *args )
  end

  def self.respond_to_missing?( method, include_private = false )
    fake_instance.respond_to?( method, include_private )
  end

  def controller
    @controller ||= ApplicationController
  end

  def method_missing( method, *args )
    controller.send( method, *args )
  rescue NoMethodError
    controller.helpers.send( method, *args )
  end

  def respond_to_missing?( method, include_private = false )
    controller.send( :respond_to_missing?, method, include_private ) || controller.helpers.send( :respond_to_missing?, method, include_private )
  end

  # Overriding this so that assets we have chosen not to be used with a digest
  # don't actually use a digest
  def asset_path( source, options = {} )
    if source !~ /^http/ && source =~ /#{NonStupidDigestAssets.whitelist.join( "|" )}/
      return "/assets/#{source}"
    end

    super( source, options )
  end
end

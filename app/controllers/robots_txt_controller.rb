# frozen_string_literal: true

class RobotsTxtController < ApplicationController
  skip_before_action( *_process_action_callbacks.map( &:filter ), raise: false )
  skip_around_action :set_time_zone, :logstash_catchall, raise: false
  before_action :set_site

  MAIN_SITE_ROBOTS_TEMPLATE_PATH = Rails.root.join( "public", "robots-www.txt" )
  PARTNER_ROBOTS_TEMPLATE_PATH = Rails.root.join( "public", "robots-partners.txt" )

  def robots
    if @site == Site.default
      render plain: main_robots_content, content_type: "text/plain; charset=utf-8"
      return
    end

    render plain: partner_robots_content, content_type: "text/plain; charset=utf-8"
  end

  private

  def main_robots_content
    template = read_robots_template( MAIN_SITE_ROBOTS_TEMPLATE_PATH )
    sitemap_url = URI.join( @site.url, "sitemap-www/sitemap.xml" ).to_s
    [template, "Sitemap: #{sitemap_url}", ""].join( "\n" )
  end

  def partner_robots_content
    template = read_robots_template( PARTNER_ROBOTS_TEMPLATE_PATH )
    sitemap_url = URI.join( @site.url, "sitemap-partners/sitemap-#{@site.id}.xml" ).to_s
    [template, "Sitemap: #{sitemap_url}", ""].join( "\n" )
  end

  def read_robots_template( path )
    return "" unless File.file?( path )

    File.read( path ).rstrip
  end
end

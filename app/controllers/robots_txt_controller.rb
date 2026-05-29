# frozen_string_literal: true

class RobotsTxtController < ActionController::Base
  MAIN_SITE_ROBOTS_TEMPLATE_PATH = Rails.root.join( "public", "robots-www.txt" )
  PARTNER_ROBOTS_TEMPLATE_PATH = Rails.root.join( "public", "robots-partners.txt" )

  def robots
    host = request.host.to_s.downcase
    if default_site_host?( host )
      render plain: main_robots_content, content_type: "text/plain; charset=utf-8"
      return
    end

    site = Site.where( "url LIKE ?", "%#{host}%" ).first
    if site
      render plain: partner_robots_content( site ), content_type: "text/plain; charset=utf-8"
      return
    end

    render plain: default_robots_content, content_type: "text/plain; charset=utf-8"
  end

  private

  def main_robots_content
    site = Site.default
    return default_robots_content unless site

    template = read_robots_template( MAIN_SITE_ROBOTS_TEMPLATE_PATH )
    sitemap_url = "#{base_url_for_site( site )}/sitemap-www/sitemap.xml"
    [template, "Sitemap: #{sitemap_url}", ""].join( "\n" )
  end

  def partner_robots_content( site )
    template = read_robots_template( PARTNER_ROBOTS_TEMPLATE_PATH )
    sitemap_url = "#{base_url_for_site( site )}/sitemap-partners/sitemap-#{site.id}.xml"
    [template, "Sitemap: #{sitemap_url}", ""].join( "\n" )
  end

  def read_robots_template( path )
    return "" unless File.file?( path )

    File.read( path ).rstrip
  end

  def base_url_for_site( site )
    site.url.to_s.sub( %r{/$}, "" )
  end

  def default_site_host?( host )
    Site.default&.url.to_s.downcase.include?( host )
  end

  def default_robots_content
    <<~ROBOTS
      User-agent: *
      Disallow: /
    ROBOTS
  end
end

# frozen_string_literal: true

require "cgi"
require "fileutils"
require "uri"

module Sitemap
  class SitemapPartnerSitemapGenerator
    STATIC_ALLOWED_PATHS = %w(/blog /login /signup).freeze
    DYNAMIC_URL_METHODS = %i[
      about_url
      help_url
      getting_started_url
      community_guidelines_url
    ].freeze
    OUTPUT_DIR = Rails.root.join( "public", "sitemap-partners" )

    class << self
      def output_dir
        OUTPUT_DIR
      end
    end

    def initialize( output_dir: nil )
      @output_dir = Pathname.new( output_dir || self.class.output_dir )
    end

    def generate!
      FileUtils.mkdir_p( @output_dir )
      generated_count = 0

      Site.live.find_each do | site |
        site_data = site_data_for( site )
        next unless site_data

        write_sitemap_file(
          site_data[:sitemap_filename],
          site_data[:base_url],
          site_data[:allowed_paths],
          site_data[:site_url]
        )
        generated_count += 1
      end

      puts "[seo] generated partner sitemaps for #{generated_count} sites in #{@output_dir}"
    end

    private

    def site_data_for( site )
      site_uri = parse_site_uri( site.url )
      return nil unless site_uri

      host = site_uri.host.to_s.downcase
      return nil if host.blank?

      {
        site_url: site.url.to_s,
        base_url: base_url_from_uri( site_uri ),
        allowed_paths: allowed_paths_for_site( site, host ),
        sitemap_filename: "sitemap-#{site.id}.xml"
      }
    end

    def parse_site_uri( raw_url )
      return nil if raw_url.blank?

      URI.parse( raw_url.to_s )
    rescue URI::InvalidURIError
      nil
    end

    def base_url_from_uri( site_uri )
      scheme = site_uri.scheme.presence || "https"
      host = site_uri.host
      default_port = ( scheme == "https" ) ? 443 : 80
      port_part = ( site_uri.port == default_port ) ? "" : ":#{site_uri.port}"
      "#{scheme}://#{host}#{port_part}"
    end

    def allowed_paths_for_site( site, host )
      dynamic_paths = DYNAMIC_URL_METHODS.filter_map do | method_name |
        normalize_path_for_site( site.public_send( method_name ), host )
      end
      blog_paths = blog_post_paths_for_site( site )
      featured_project_paths = featured_project_paths_for_site( site )
      ( ["/"] + STATIC_ALLOWED_PATHS + dynamic_paths + blog_paths + featured_project_paths ).uniq
    end

    def blog_post_paths_for_site( site )
      Post.published.
        where( parent_type: "Site", parent_id: site.id ).
        not_flagged_as_spam.
        select( :id, :title ).
        order( :id ).
        map {| post | "/blog/#{post.to_param}" }
    end

    def featured_project_paths_for_site( site )
      site.site_featured_projects.
        joins( :project ).
        merge( Project.not_flagged_as_spam ).
        includes( :project ).
        order( "site_featured_projects.updated_at DESC" ).
        map do | featured_project |
          project = featured_project.project
          "/projects/#{project.slug.presence || project.id}"
        end
    end

    def normalize_path_for_site( raw_value, host )
      return nil if raw_value.blank?

      value = raw_value.to_s.strip
      return nil if value.blank?

      if value.start_with?( "/" )
        return value
      end

      uri = URI.parse( value )
      return nil if uri.host.present? && uri.host.downcase != host

      path = uri.path.presence || "/"
      path = "/#{path}" unless path.start_with?( "/" )
      path
    rescue URI::InvalidURIError
      nil
    end

    def write_sitemap_file( filename, base_url, allowed_paths, site_url )
      File.open( @output_dir.join( filename ), "w:UTF-8" ) do | io |
        io.write( %(<?xml version="1.0" encoding="UTF-8"?>\n) )
        io.write( %(<!-- Generated for #{CGI.escapeHTML( site_url )} -->\n) )
        io.write( %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n) )
        allowed_paths.each do | path |
          loc = "#{base_url}#{path}"
          io.write( "  <url><loc>#{CGI.escapeHTML( loc )}</loc></url>\n" )
        end
        io.write( %(</urlset>\n) )
      end
    end
  end
end

# frozen_string_literal: true

require "cgi"
require "fileutils"
require "uri"

module Sitemap
  class SitemapPartnerSitemapGenerator
    STATIC_ALLOWED_URL_METHODS = %i[
      root_url
      site_posts_url
      login_url
      signup_url
    ].freeze
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
          site_data[:allowed_urls],
          site_data[:site_url]
        )
        generated_count += 1
      end

      puts "[seo] generated partner sitemaps for #{generated_count} sites in #{@output_dir}"
    end

    private

    def site_data_for( site )
      {
        site_url: site.url.to_s,
        allowed_urls: allowed_urls_for_site( site ),
        sitemap_filename: "sitemap-#{site.id}.xml"
      }
    end

    def allowed_urls_for_site( site )
      FakeView.set_default_url_options_from_site( site )
      static_urls = STATIC_ALLOWED_URL_METHODS.filter_map do | method_name |
        next unless FakeView.respond_to?( method_name )

        FakeView.public_send( method_name )
      end
      dynamic_urls = DYNAMIC_URL_METHODS.filter_map do | method_name |
        site.public_send( method_name ).presence
      end
      blog_post_urls = blog_post_urls_for_site( site )
      featured_project_urls = featured_project_urls_for_site( site )
      ( static_urls + dynamic_urls + blog_post_urls + featured_project_urls ).uniq
    end

    def blog_post_urls_for_site( site )
      Post.published.
        where( parent_type: "Site", parent_id: site.id ).
        not_flagged_as_spam.
        select( :id, :title, :slug ).
        order( :id ).
        map {| post | FakeView.site_post_url( post ) }
    end

    def featured_project_urls_for_site( site )
      site.site_featured_projects.
        joins( :project ).
        merge( Project.not_flagged_as_spam ).
        includes( :project ).
        order( "site_featured_projects.updated_at DESC" ).
        map do | featured_project |
          project = featured_project.project
          FakeView.project_url( project )
        end
    end

    def write_sitemap_file( filename, allowed_urls, site_url )
      File.open( @output_dir.join( filename ), "w:UTF-8" ) do | io |
        io.write( %(<?xml version="1.0" encoding="UTF-8"?>\n) )
        io.write( %(<!-- Generated for #{CGI.escapeHTML( site_url )} -->\n) )
        io.write( %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n) )
        allowed_urls.each do | loc |
          io.write( "  <url><loc>#{CGI.escapeHTML( loc )}</loc></url>\n" )
        end
        io.write( %(</urlset>\n) )
      end
    end
  end
end

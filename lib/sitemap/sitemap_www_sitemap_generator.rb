# frozen_string_literal: true

require "cgi"
require "fileutils"
require "tmpdir"
require "zlib"

module Sitemap
  class SitemapWwwSitemapGenerator
    MAX_URLS_PER_SITEMAP = 50_000
    DEFAULT_CHUNK_SIZE = 45_000
    DEFAULT_BATCH_SIZE = 2_000
    OUTPUT_DIR = Rails.root.join( "public", "sitemap-www" ).to_s
    ROOT_INDEX_PATH = File.join( OUTPUT_DIR, "sitemap.xml" )
    PUBLIC_URL_PREFIX = "/sitemap-www"
    XML_HEADER = %(<?xml version="1.0" encoding="UTF-8"?>\n)
    URLSET_OPEN = %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
    URLSET_CLOSE = %(</urlset>\n)
    INDEX_OPEN = %(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
    INDEX_CLOSE = %(</sitemapindex>\n)

    def initialize( chunk_size: nil, batch_size: nil )
      @base_url = Site.default&.url.to_s.sub( %r{/$}, "" )
      raise ArgumentError, "Could not determine base URL from Site.default.url" if @base_url.blank?

      @output_dir = OUTPUT_DIR
      @chunk_size = ( chunk_size.presence || DEFAULT_CHUNK_SIZE ).to_i
      @batch_size = ( batch_size.presence || DEFAULT_BATCH_SIZE ).to_i
      validate_options!
    end

    def generate!
      start = Time.now
      puts "[sitemap] writing sitemap files to #{@output_dir}"
      puts "[sitemap] base URL: #{@base_url}"
      puts "[sitemap] chunk size: #{@chunk_size} URLs"
      puts "[sitemap] root index: #{ROOT_INDEX_PATH}"

      tmp_work_dir = Dir.mktmpdir( "inat-sitemaps-", "/tmp" )
      tmp_dir = File.join( tmp_work_dir, "sitemaps" )
      root_index_tmp_path = File.join( tmp_work_dir, "sitemap.xml" )
      FileUtils.mkdir_p( tmp_dir )

      category_results = []
      category_results << generate_projects( tmp_dir )
      category_results << generate_taxa( tmp_dir )
      # category_results << generate_people( tmp_dir )
      category_results << generate_places( tmp_dir )
      category_results << generate_blog_posts( tmp_dir )
      # category_results << generate_user_journal_posts( tmp_dir )
      category_results << generate_project_journal_posts( tmp_dir )

      write_root_index( root_index_tmp_path, category_results.map {| result | result[:index_filename] } )
      publish!( tmp_dir, root_index_tmp_path )
      print_summary( category_results )

      puts "[sitemap] done in #{( Time.now - start ).round( 2 )}s"
    ensure
      FileUtils.rm_rf( tmp_work_dir ) if tmp_work_dir && File.exist?( tmp_work_dir )
    end

    private

    def validate_options!
      raise ArgumentError, "chunk_size must be >= 1" if @chunk_size <= 0
      raise ArgumentError, "batch_size must be >= 1" if @batch_size <= 0
      return unless @chunk_size > MAX_URLS_PER_SITEMAP

      raise ArgumentError, "chunk_size must be <= #{MAX_URLS_PER_SITEMAP}"
    end

    def publish!( tmp_dir, root_index_tmp_path )
      FileUtils.rm_rf( @output_dir )
      FileUtils.mkdir_p( File.dirname( @output_dir ) )
      FileUtils.mv( tmp_dir, @output_dir )
      FileUtils.rm_f( ROOT_INDEX_PATH )
      FileUtils.mv( root_index_tmp_path, ROOT_INDEX_PATH )
    end

    def write_root_index( file_path, category_indexes )
      write_xml( file_path ) do | io |
        io.write( INDEX_OPEN )
        category_indexes.each do | filename |
          write_index_entry( io, filename )
        end
        io.write( INDEX_CLOSE )
      end
    end

    def generate_projects( dir )
      relation = Project.not_flagged_as_spam.select( :id, :slug, :title ).distinct.order( :id )
      generate_category( dir, "projects", relation ) do | project |
        "/projects/#{project.slug.presence || project.id}"
      end
    end

    def generate_taxa( dir )
      relation = Taxon.active.select( :id, :name ).order( :id )
      generate_category( dir, "taxa", relation ) do | taxon |
        "/taxa/#{taxon.to_param}"
      end
    end

    def generate_people( dir )
      relation = User.active.
        where( "spammer = ? OR spammer IS NULL", false ).
        select( :id, :login ).order( :id )
      generate_category( dir, "people", relation ) do | user |
        "/people/#{user.login}"
      end
    end

    def generate_places( dir )
      relation = Place.select( :id, :slug ).order( :id )
      generate_category( dir, "places", relation ) do | place |
        "/places/#{place.slug.presence || place.id}"
      end
    end

    def generate_blog_posts( dir )
      relation = Post.published.
        where( parent_type: "Site" ).
        not_flagged_as_spam.
        select( :id, :title ).
        order( :id )
      generate_category( dir, "blog-posts", relation ) do | post |
        "/blog/#{post.to_param}"
      end
    end

    def generate_user_journal_posts( dir )
      relation = Post.published.
        where( parent_type: "User" ).
        not_flagged_as_spam.
        joins( :user ).
        merge( User.active ).
        includes( :user ).
        select( :id, :title, :user_id ).
        distinct.
        order( :id )
      generate_category( dir, "journal-posts", relation ) do | post |
        "/journal/#{post.user.login}/#{post.to_param}"
      end
    end

    def generate_project_journal_posts( dir )
      relation = Post.published.
        where( parent_type: "Project" ).
        not_flagged_as_spam.
        joins( "JOIN projects ON projects.id = posts.parent_id" ).
        select( "posts.id, posts.title, posts.parent_id, projects.slug AS project_slug" ).
        order( "posts.id" )
      generate_category( dir, "project-journal-posts", relation ) do | post |
        project_key = post.read_attribute( "project_slug" ).presence || post.parent_id
        "/projects/#{project_key}/journal/#{post.to_param}"
      end
    end

    def generate_category( dir, category, relation )
      puts "[sitemap] generating #{category}"
      chunk_filenames = []
      writer = nil
      total = 0
      samples = []
      batch_index = 0
      category_started_at = Time.now

      relation.find_in_batches( batch_size: @batch_size ) do | batch |
        batch_index += 1
        batch_started_at = Time.now
        batch.each do | record |
          if writer.nil? || writer[:count] >= @chunk_size
            close_chunk_writer( writer, chunk_filenames ) if writer
            writer = open_chunk_writer( dir, category, chunk_filenames.length + 1 )
            puts "[sitemap] #{category}: opened #{writer[:filename]} (chunk #{chunk_filenames.length + 1})"
          end

          path = yield( record )
          url = absolute_url( path )
          writer[:io].write( "  <url><loc>#{xml_escape( url )}</loc></url>\n" )
          writer[:count] += 1
          total += 1
          samples << url if samples.size < 5
        end
        elapsed = ( Time.now - category_started_at ).round( 1 )
        batch_time = ( Time.now - batch_started_at ).round( 1 )
        puts "[sitemap] #{category}: batch #{batch_index} processed #{batch.size} rows, " \
          "total=#{total}, elapsed=#{elapsed}s, batch_time=#{batch_time}s"
      end

      close_chunk_writer( writer, chunk_filenames ) if writer

      index_filename = "sitemap-#{category}-index.xml"
      write_xml( File.join( dir, index_filename ) ) do | io |
        io.write( INDEX_OPEN )
        chunk_filenames.each do | chunk_filename |
          write_index_entry( io, chunk_filename )
        end
        io.write( INDEX_CLOSE )
      end

      duration = ( Time.now - category_started_at ).round( 1 )
      puts "[sitemap] #{category}: #{total} URLs across #{chunk_filenames.size} files (done in #{duration}s)"
      {
        name: category,
        index_filename: index_filename,
        count: total,
        duration_seconds: duration,
        samples: samples
      }
    end

    def print_summary( category_results )
      puts "[sitemap] summary by category"
      category_results.each do | result |
        puts "[sitemap] #{result[:name]}: count=#{result[:count]}, duration=#{result[:duration_seconds]}s"
        result[:samples].each_with_index do | url, index |
          puts "[sitemap]   sample#{index + 1}: #{url}"
        end
      end
    end

    def open_chunk_writer( dir, category, chunk_number )
      filename = format( "sitemap-%<category>s-%<chunk>04d.xml.gz", category: category, chunk: chunk_number )
      path = File.join( dir, filename )
      io = Zlib::GzipWriter.open( path )
      io.write( XML_HEADER )
      io.write( URLSET_OPEN )
      { io: io, filename: filename, count: 0 }
    end

    def close_chunk_writer( writer, chunk_filenames )
      writer[:io].write( URLSET_CLOSE )
      writer[:io].close
      chunk_filenames << writer[:filename]
    end

    def write_xml( file_path )
      File.open( file_path, "w:UTF-8" ) do | io |
        io.write( XML_HEADER )
        yield io
      end
    end

    def write_index_entry( io, filename )
      url = absolute_url( "#{PUBLIC_URL_PREFIX}/#{filename}" )
      io.write( "  <sitemap><loc>#{xml_escape( url )}</loc></sitemap>\n" )
    end

    def absolute_url( path )
      normalized_path = path.start_with?( "/" ) ? path : "/#{path}"
      "#{@base_url}#{normalized_path}"
    end

    def xml_escape( value )
      CGI.escapeHTML( value.to_s )
    end
  end
end

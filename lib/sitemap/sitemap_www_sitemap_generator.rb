# frozen_string_literal: true

require "cgi"
require "fileutils"
require "tmpdir"
require "zlib"

module Sitemap
  class SitemapWwwSitemapGenerator
    MAX_URLS_PER_SITEMAP = 50_000
    DEFAULT_CHUNK_SIZE = 10_000
    DEFAULT_BATCH_SIZE = 2_000
    MAX_PHOTOS_PER_TAXON = 5
    OUTPUT_DIR = Rails.root.join( "public", "sitemap-www" ).to_s
    ROOT_INDEX_PATH = File.join( OUTPUT_DIR, "sitemap.xml" )
    PUBLIC_URL_PREFIX = "/sitemap-www"
    XML_HEADER = %(<?xml version="1.0" encoding="UTF-8"?>\n)
    URLSET_OPEN = %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
    URLSET_IMAGE_OPEN = %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">\n)
    URLSET_CLOSE = %(</urlset>\n)
    INDEX_OPEN = %(<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
    INDEX_CLOSE = %(</sitemapindex>\n)

    def initialize( chunk_size: nil, batch_size: nil )
      @base_url = Site.default&.url.to_s.sub( %r{/$}, "" )
      raise ArgumentError, "Could not determine base URL from Site.default.url" if @base_url.blank?

      FakeView.set_default_url_options_from_site( Site.default )

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
      ( I18N_SUPPORTED_LOCALES - ["en"] ).each do | locale |
        result = generate_taxa_for_locale( tmp_dir, locale )
        category_results << result if result
      end
      category_results << generate_people( tmp_dir )
      category_results << generate_places( tmp_dir )
      category_results << generate_blog_posts( tmp_dir )
      category_results << generate_user_journal_posts( tmp_dir )
      category_results << generate_project_journal_posts( tmp_dir )

      write_root_index( root_index_tmp_path, category_results.flat_map {| result | result[:chunk_filenames] } )
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
      FileUtils.rm_rf( Dir.glob( "#{@output_dir}/*" ) )
      FileUtils.mv( Dir.glob( "#{tmp_dir}/*" ), @output_dir )
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
      relation = Project.not_flagged_as_spam.select( :id, :slug ).distinct.order( :id )
      generate_category( dir, "projects", relation ) do | project |
        FakeView.project_url( project )
      end
    end

    def generate_taxa( dir )
      relation = Taxon.active.select( :id, :name ).order( :id )
      generate_category( dir, "taxa", relation, image_namespace: true,
        preload: method( :preload_taxa_batch ) ) do | taxon, ctx |
        common = ctx[:common_names][taxon.id]
        taxon_label = common ? "#{taxon.name} (#{common})" : taxon.name
        images = ( ctx[:photos_by_taxon][taxon.id] || [] ).map do | photo_data |
          attribution = photo_data[:attribution_name].presence || I18n.t( "copyright.anonymous" )
          { loc: photo_data[:url], title: "#{taxon_label} photographed by #{attribution}",
            license: photo_data[:license] }
        end
        { url: FakeView.taxon_url( taxon ), images: images }
      end
    end

    def generate_taxa_for_locale( dir, locale )
      lexicon_key = TaxonName::LEXICONS_BY_LOCALE[locale]
      return unless lexicon_key

      lexicon = TaxonName::LEXICONS[lexicon_key.upcase.to_sym]
      return unless lexicon

      relation = Taxon.active.
        joins( :taxon_names ).
        where( taxon_names: { lexicon: lexicon, is_valid: true } ).
        select( "taxa.id, taxa.name" ).
        distinct.
        order( "taxa.id" )

      category = "taxa-#{locale.downcase.gsub( /[^a-z0-9]/, '-' )}"
      generate_category( dir, category, relation ) do | taxon |
        FakeView.localized_taxon_url( locale: locale, id: taxon.to_param )
      end
    end

    def generate_people( dir )
      relation = User.active.
        where( "spammer = ? OR spammer IS NULL", false ).
        where( "login ~ ?", "^[[:alnum:]_][^.,/]+$" ).
        where(
          "observations_count > 0 OR identifications_count > 0 OR journal_posts_count > 0 OR " \
            "BTRIM( COALESCE( description, '' ) ) != ''"
        ).
        select( :id, :login ).order( :id )
      generate_category( dir, "people", relation ) do | user |
        FakeView.person_by_login_url( login: user.login )
      end
    end

    def generate_places( dir )
      relation = Place.select( :id, :slug ).order( :id )
      generate_category( dir, "places", relation ) do | place |
        FakeView.place_url( place )
      end
    end

    def generate_blog_posts( dir )
      relation = Post.published.
        where( parent_type: "Site" ).
        not_flagged_as_spam.
        select( :id, :title ).
        order( :id )
      generate_category( dir, "blog-posts", relation ) do | post |
        FakeView.site_post_url( post )
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
        FakeView.journal_post_url( login: post.user.login, id: post.to_param )
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
        FakeView.project_journal_post_url( project_id: project_key, id: post.to_param )
      end
    end

    def preload_taxa_batch( batch )
      taxon_ids = batch.map( &:id )

      common_names = TaxonName.
        where( taxon_id: taxon_ids, is_valid: true ).
        where( lexicon: TaxonName::LEXICONS[:ENGLISH] ).
        order( "taxon_id ASC, position ASC NULLS LAST, id ASC" ).
        pluck( :taxon_id, :name ).
        each_with_object( {} ) {| ( tid, name ), h | h[tid] ||= name }

      @file_prefixes ||= FilePrefix.all.index_by( &:id )
      @file_extensions ||= FileExtension.all.index_by( &:id )

      photos_by_taxon = TaxonPhoto.
        where( taxon_id: taxon_ids ).
        includes( { photo: [:user, :flags, :moderator_actions] } ).
        order( "taxon_id, position ASC NULLS LAST, id ASC" ).
        group_by( &:taxon_id ).
        transform_values do | taxon_grouped_photos |
          taxon_grouped_photos.first( MAX_PHOTOS_PER_TAXON ).filter_map do | taxon_photo |
            photo = taxon_photo.photo
            next unless photo.is_a?( LocalPhoto )
            next if photo.user.blank?
            next if photo.license == Shared::LicenseModule::COPYRIGHT
            next if photo.flags.any? {| f | !f.resolved? }
            next if photo.hidden?

            file_prefix = @file_prefixes[photo.file_prefix_id]
            file_extension = @file_extensions[photo.file_extension_id]
            next unless file_prefix && file_extension

            attribution_name = photo.native_realname.presence || photo.native_username.presence ||
              photo.user.name.presence || photo.user.login.presence
            {
              url: "#{file_prefix.prefix}/#{photo.id}/medium.#{file_extension.extension}",
              attribution_name: attribution_name,
              license: photo.license_url
            }
          end
        end

      { common_names: common_names, photos_by_taxon: photos_by_taxon }
    end

    def generate_category( dir, category, relation, image_namespace: false, preload: nil )
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
        ctx = preload&.call( batch )
        batch.each do | record |
          if writer.nil? || writer[:count] >= @chunk_size
            close_chunk_writer( writer, chunk_filenames ) if writer
            writer = open_chunk_writer( dir, category, chunk_filenames.length + 1,
              image_namespace: image_namespace )
            puts "[sitemap] #{category}: opened #{writer[:filename]} (chunk #{chunk_filenames.length + 1})"
          end

          result = yield( record, ctx )
          url, images = result.is_a?( Hash ) ? [result[:url], result[:images]] : [result, nil]
          entry = "  <url><loc>#{xml_escape( url )}</loc>"
          images&.each do | img |
            entry += "\n    <image:image>" \
              "\n      <image:loc>#{xml_escape( img[:loc] )}</image:loc>" \
              "\n      <image:title>#{xml_escape( img[:title] )}</image:title>"
            entry += "\n      <image:license>#{xml_escape( img[:license] )}</image:license>" if img[:license].present?
            entry += "\n    </image:image>"
          end
          entry += "</url>\n"
          writer[:io].write( entry )
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

      duration = ( Time.now - category_started_at ).round( 1 )
      puts "[sitemap] #{category}: #{total} URLs across #{chunk_filenames.size} files (done in #{duration}s)"
      {
        name: category,
        chunk_filenames: chunk_filenames,
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

    def open_chunk_writer( dir, category, chunk_number, image_namespace: false )
      filename = format( "sitemap-%<category>s-%<chunk>04d.xml.gz", category: category, chunk: chunk_number )
      path = File.join( dir, filename )
      io = Zlib::GzipWriter.open( path )
      io.write( XML_HEADER )
      io.write( image_namespace ? URLSET_IMAGE_OPEN : URLSET_OPEN )
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
      root = FakeView.root_url.to_s.sub( %r{/$}, "" )
      url = "#{root}#{PUBLIC_URL_PREFIX}/#{filename}"
      io.write( "  <sitemap><loc>#{xml_escape( url )}</loc></sitemap>\n" )
    end

    def xml_escape( value )
      CGI.escapeHTML( value.to_s )
    end
  end
end

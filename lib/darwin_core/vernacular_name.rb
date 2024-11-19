# frozen_string_literal: true

# Several terms need to be camelcase
# rubocop:disable Naming/MethodName

module DarwinCore
  class VernacularName
    include Helpers

    TERMS = [
      ["id", "id", nil, "core_id"],

      # http://rs.gbif.org/terms/1.0/VernacularName
      %w(vernacularName http://rs.tdwg.org/dwc/terms/vernacularName),
      %w(language http://purl.org/dc/terms/language),
      %w(locality http://rs.tdwg.org/dwc/terms/locality),
      %w(countryCode http://rs.tdwg.org/dwc/terms/countryCode),
      ["source", "http://purl.org/dc/terms/source", nil, "dwc_source"],

      # Specific to iNat
      %w(lexicon https://www.inaturalist.org/terms/lexicon),
      %w(contributor http://purl.org/dc/elements/1.1/contributor),
      %w(created http://purl.org/dc/terms/created)
    ].freeze
    TERM_NAMES = TERMS.map {| name, _uri | name }

    def self.adapt( record, options = {} )
      record.extend( InstanceMethods )
      record.core = options[:core]
      record
    end

    module InstanceMethods
      attr_accessor :core

      def core_id
        taxon_id
      end

      def vernacularName
        name
      end

      def dwc_source
        if source
          source.try_methods( :citation, :url, :title )
        elsif !source_url.blank?
          source_url
        end
      end

      def language
        locale_for_lexicon
      end

      def locality
        place_taxon_names.map {| ptn | ptn.place.try( :display_name ) }.compact.join( " | " )
      end

      def countryCode
        codes = []
        if ( locale_pieces = locale_for_lexicon.split( "-" ) ) && locale_pieces[1]
          codes << locale_pieces[1]
        end
        codes += place_taxon_names.
          select {| ptn | ptn.place && ptn.place.admin_level == Place::COUNTRY_LEVEL }.
          map {| ptn | ptn.place.code }
        codes.reject( &:blank? ).join( "," )
      end

      def contributor
        return unless ( user = creator || updater )

        user.name.blank? ? user.login : user.name
      end

      def created
        created_at.iso8601
      end
    end

    def self.descriptor
      {
        row_type: "http://rs.gbif.org/terms/1.0/VernacularName",
        files: file_names.values,
        terms: TERMS
      }
    end

    def self.data( options = {} )
      unless options[:core] == DarwinCore::Cores::TAXON
        raise "VernacularNames extension can only be used with a taxon core"
      end

      # fname = "vernacular_names.csv"
      if options[:work_path]
        work_path = options[:work_path]
      else
        work_path = Dir.mktmpdir
        FileUtils.mkdir_p work_path, mode: 0o755
      end
      paths = []
      file_names.each do | lexicon, fname |
        tmp_path = File.join( work_path, fname )
        mode = File.exist?( tmp_path ) ? "a" : "w"
        CSV.open( tmp_path, mode ) do | csv |
          csv << TERM_NAMES if mode == "w"
          DarwinCore::VernacularName.base_scope.
            where( lexicon: lexicon ).
            includes( :taxon, :source, :creator, :updater, place_taxon_names: :place ).
            order( "taxon_id" ).
            find_each do | tn |
            DarwinCore::VernacularName.adapt( tn, core: options[:core] )
            csv << DarwinCore::VernacularName::TERMS.map {| field, _uri, _default, method | tn.send( method || field ) }
          end
        end
        paths << tmp_path
      end
      paths
    end

    def self.base_scope
      # Note that records with a null `lexicon` field should be included and
      # should receive a language of `und`. Some users use the archive to
      # look for names to fix.
      TaxonName.joins( :taxon ).
        where( "taxa.is_active" ).
        where( "lexicon IS NULL OR lexicon != ?", TaxonName::SCIENTIFIC_NAMES )
    end

    def self.file_names
      lexicons = base_scope.select( "DISTINCT lexicon" ).pluck( :lexicon ).uniq
      lexicons.each_with_object( {} ) do | lexicon, memo |
        memo[lexicon] = "VernacularNames-#{( lexicon.blank? ? 'unknown' : lexicon ).parameterize}.csv"
      end
    end
  end
end
# rubocop:enable Naming/MethodName

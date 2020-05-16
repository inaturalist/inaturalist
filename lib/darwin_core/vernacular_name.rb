module DarwinCore
  class VernacularName
    include Helpers

    TERMS = [
      ['id', 'id', nil, 'core_id'],

      # http://rs.gbif.org/terms/1.0/VernacularName
      %w(vernacularName http://rs.tdwg.org/dwc/terms/vernacularName),
      %w(language http://purl.org/dc/terms/language),
      %w(locality http://rs.tdwg.org/dwc/terms/locality),
      %w(countryCode http://rs.tdwg.org/dwc/terms/countryCode),
      ["source", "http://purl.org/dc/terms/source", nil, "dwc_source"],

      # Specific to iNat
      %w(lexicon https://www.inaturalist.org/terms/lexicon),
      %w(contributor http://purl.org/dc/elements/1.1/contributor),
      %w(created http://purl.org/dc/terms/created),
    ]
    TERM_NAMES = TERMS.map{|name, uri| name}

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
          source.try_methods(:citation, :url, :title)
        elsif !source_url.blank?
          source_url
        end
      end

      def language
        locale_for_lexicon
      end

      def locality
        place_taxon_names.map{|ptn| ptn.place.display_name}.join( " | " )
      end

      def countryCode
        codes = []
        if ( locale_pieces = locale_for_lexicon.split("-") ) && locale_pieces[1]
          codes << locale_pieces[1]
        end
        codes += place_taxon_names.map{|ptn| ptn.place.admin_level == Place::COUNTRY_LEVEL && ptn.place.code}
        codes.select{|c| !c.blank?}.join( "," )
      end

      def contributor
        if user = creator || updater
          user.name.blank? ? user.login : user.name
        end
      end

      def created
        created_at.iso8601
      end
    end
  end
end

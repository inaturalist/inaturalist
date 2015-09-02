module Ratatosk
  module NameProviders
    #
    # Concrete strategy for getting names from the Catalogue of Life
    #
    class EolNameProvider
      cattr_accessor :source
      
      def self.source
        @source ||= ::Source.find_by_title("Encyclopedia of Life") || ::Source.create(
          :title => "Encyclopedia of Life",
          :in_text => "EOL",
          :url => "http://www.eol.org",
          :citation => "Encyclopedia of Life. Available from http://www.eol.org."
        )
      end

      def initialize
        @service = EolService.new(:timeout => 10, :debug => true)
      end

      def find(name)
        hxml = @service.search(name)
        unless hxml.errors.blank?
          raise NameProviderError, "Failed to parse the response from the Catalogue of Life: #{hxml.errors}"
        end
        hxml.search('entry')[0..9].map do |entry|
          matching_names = entry.at('content').text.split(';').map{|n| TaxonName.strip_author(n)}
          matching_name = matching_names.detect{|n| n.index(name)}
          if matching_name && (page = @service.page(entry.at('id').text)) && page.to_s.index(name)
            EolTaxonNameAdapter.new(page)
          end
        end.compact
      end

      #
      # Finds a taxon's ancestors from the name provider and returns an array
      # of them as *new* Taxon objects up until there is one already in our
      # database. Thus, the first Taxon in the array should either be a new
      # Kingdom or an existing saved Taxon that is already in our local tree.
      #
      def get_lineage_for(taxon)
        puts "taxon.preferred_hierarchy_id: #{taxon.preferred_hierarchy_id}"
        hxml = if (hierarchy_id = taxon.preferred_hierarchy_id)
          @service.hierarchy_entries(hierarchy_id)
        end
        lineage = [taxon]

        if hxml
          # walk UP the Eol lineage creating new taxa
          [hxml.xpath('//dwc:taxon')].flatten.reverse_each do |ancestor_hxml|
            lineage << EolTaxonAdapter.new(ancestor_hxml)
            puts "lineage.last: #{lineage.last}"
          end
        end
        lineage.compact
      end
      
      # Gets the phylum name for this taxon.
      def get_phylum_for(taxon, lineage = nil)
        lineage ||= get_lineage_for(taxon)
        phylum = lineage.select{|t| t.rank && t.rank.downcase == 'phylum'}.first
        phylum ||= lineage.last.phylum
        phylum
      end
    end

    class EolTaxonNameAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon_name :adaptee
      
      #
      # Initialize with an Hpricot object of a single Eol XML response
      #
      def initialize(hxml, params = {})
        @adaptee = TaxonName.new(params)
        @hxml = hxml
        taxon_name.name ||= TaxonName.strip_author(
          @hxml.at('//dwc:scientificName').try(:inner_text) || @hxml.at('//commonName').try(:inner_text)
        )
        taxon_name.lexicon = get_lexicon
        taxon_name.is_valid = get_is_valid
        taxon_name.source = EolNameProvider.source
        taxon_name.source_identifier = @hxml.at('//taxonConceptID').try(:text) || @hxml.at('//dwc:taxonID').try(:text)
        taxon_name.source_url = "http://eol.org/pages/#{taxon_name.source_identifier}"
        taxon_name.taxon = taxon
        taxon_name.name_provider = "EolNameProvider"
      end
      
      # Override taxon to make sure we always check to see if a taxon for this
      # name has been saved since the creation of this name's temporary taxon
      def taxon
        @taxon ||= get_taxon
      end
      
      # Overriden to make sure we always check to see if a taxon for this
      # name has been saved since the creation of this name's temporary taxon
      def save
        if taxon_name.taxon.nil? or taxon_name.taxon.new_record?
          taxon_name.taxon = taxon
        end
        taxon_name.save
      end
      
      protected

      def service
        @service ||= EolService.new(:timeout => 10)
      end

      def get_lexicon
        elt = name_elt
        return nil if elt.blank?
        lex = if elt.name == "scientificName" || elt.name == "synonym"
          TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
        else
          TaxonName.language_for_locale(elt['xml:lamg'])
        end
        lex == 'unspecified' ? nil : lex
      end

      def name_elt
        elts = @hxml.xpath("//dwc:scientificName|//synonym|//commonName")
        puts "elts: #{elts.map{|e| TaxonName.strip_author(e.text) }.inspect}"
        puts "name: #{name}"
        elts.detect{|e| TaxonName.strip_author(e.text) == name} || elts.detect{|e| TaxonName.strip_author(e.text).index(name)}
      end

      def get_is_valid
        return true if is_comname?
        name_elt.name == "scientificName"
      end

      #
      # Test if this is a common / vernacular name
      #
      def is_comname?
        name_elt.name == "commonName"
      end

      def get_taxon
        taxon = EolTaxonAdapter.new(@hxml)
        
        # This is necessary because calling save here runs the validations,
        # sees that the Taxon is new and declares the lexion validation ok,
        # then saves the new taxon, which would fire the after save callback
        # creating another taxon name, and then this taxon name gets
        # created, resulting in duplicate, invalid taxon names.
        taxon.skip_new_taxon_name = true
        
        taxon
      end

      def is_accepted_sciname?
        # accepted_name == name
        is_comname? || name_elt.name == "scientificName"        
      end

      # def accepted_name
      #   if accepted_name_hxml
      #     accepted_name_hxml.at_xpath('dwc:scientificName').try(:inner_text)
      #   else
      #     name
      #   end
      # end

      # def accepted_name_hxml
      #   return @accepted_name_hxml unless @accepted_name_hxml.blank?
      #   xml = @hxml.at_xpath('accepted_name')
      #   @accepted_name_hxml = if xml.blank? || xml.elements.blank?
      #     if accepted_synonym_id = @hxml.at(:url).inner_text.to_s[/(\d+)\/synonym\/\d+/, 1]
      #       service.search(:id => accepted_synonym_id, :response => 'full')
      #     end
      #   else
      #     xml
      #   end
      # end
    end

    class EolTaxonAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon :adaptee
      
      #
      # Initialize with an Hpricot object of a single Eol XML response
      #
      def initialize(hxml, params = {})
        @adaptee = Taxon.new(params)
        @hxml = hxml
        @adaptee.name               = @hxml.at('//dwc:scientificName').inner_text
        @adaptee.rank               = @hxml.search('//dwc:taxonRank').map(&:text).inject({}) {|memo,rank| memo[rank] = memo[rank].to_i + 1; memo}.sort_by(&:last).last.try(:first)
        @adaptee.source             = EolNameProvider.source
        # @adaptee.source_identifier  = @hxml.at('id').inner_text
        # @adaptee.source_url         = @hxml.at('url').inner_text
        @adaptee.name_provider      = "EolNameProvider"
        @adaptee.source_identifier  = @hxml.at('//xmlns:taxonConceptID').try(:text) || @hxml.at('//dwc:taxonID').try(:text)
        @adaptee.source_url         = "http://eol.org/pages/#{@adaptee.source_identifier}"
      end

      def preferred_hierarchy_id
        @hxml.at("//xmlns:taxon/dwc:taxonID").try(:inner_text)
      end
    end
  end # module NameProviders
end # module Ratatosk

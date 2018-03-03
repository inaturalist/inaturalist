module Ratatosk
  module NameProviders
    #
    # Concrete strategy for getting names from EOL
    #
    class EolNameProvider
      cattr_accessor :source
      
      def self.source(options = {})
        return @@source if @@source && !options[:force]
        @@source = Source.find_by_title("Encyclopedia of Life") || Source.create(
          title: "Encyclopedia of Life",
          in_text: "EOL",
          url: "http://www.eol.org",
          citation: "Encyclopedia of Life. Available from http://www.eol.org."
        )
      end

      def service
        @service ||= EolService.new(timeout: 10, debug: Rails.env.development?)
      end

      def find(name)
        hxml = service.search(name)
        unless hxml.errors.blank?
          raise NameProviderError, "Failed to parse the response from the EOL: #{hxml.errors}"
        end
        names = {}
        hxml.search('entry')[0..9].each do |entry|
          page = service.page(entry.at('id').text, synonyms: true, common_names: true)
          next unless page
          next unless page.to_s =~ /#{name}/i
          tn = begin
            EolTaxonNameAdapter.new(page)
          rescue NameProviderError
            next
          end
          names[tn.name] ||= tn
          if synonym = page.xpath('//xmlns:taxonConcept/xmlns:synonym').detect{|s| TaxonName.strip_author(Taxon.remove_rank_from_name(s.text)) == name} 
            stn = names[tn.name].dup
            stn.name = TaxonName.strip_author(Taxon.remove_rank_from_name(synonym.text))
            stn.source_identifier = nil
            stn.is_valid = false
            stn.taxon = names[tn.name].taxon
            names[stn.name] = stn
          end
          if common_name = page.xpath('//xmlns:taxonConcept/xmlns:commonName').detect{|cn| cn.text =~ /#{name}/i}
            ctn = names[tn.name].dup
            ctn.name = common_name.text
            ctn.source_identifier = nil
            ctn.lexicon = TaxonName.language_for_locale(common_name['xml:lang'])
            ctn.taxon = names[tn.name].taxon
            names[ctn.name] = ctn
          end
        end
        names.values[0..9]
      end

      #
      # Finds a taxon's ancestors from the name provider and returns an array
      # of them as *new* Taxon objects up until there is one already in our
      # database. Thus, the first Taxon in the array should either be a new
      # Kingdom or an existing saved Taxon that is already in our local tree.
      #
      def get_lineage_for(taxon)
        eol_taxon = if taxon.respond_to?(:preferred_hierarchy_id)
          taxon
        else
          page = service.page(taxon.source_identifier)
          EolTaxonAdapter.new(page)
        end
        hxml = if (hierarchy_id = eol_taxon.preferred_hierarchy_id)
          service.hierarchy_entries(hierarchy_id)
        end
        lineage = []
        if hxml
          # walk UP the Eol lineage creating new taxa
          begin
            [hxml.xpath('//dwc:Taxon')].flatten.each do |ancestor_hxml|
              next if ancestor_hxml.at_xpath('dwc:taxonConceptID').nil?
              break if ancestor_hxml.at_xpath('dwc:taxonConceptID').text == taxon.source_identifier
              lineage << EolTaxonAdapter.new(ancestor_hxml)
            end
          rescue Nokogiri::XML::XPath::SyntaxError => e
            raise e unless e.message =~ /Undefined namespace prefix/
            raise NameProviderError, "Failed to load hierarchy for #{taxon.name} (higherarchy ID: #{hierarchy_id}"
          end
        end
        lineage = [taxon] + lineage.reverse
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
        is_comname? || name_elt.name == "scientificName"        
      end
    end

    class EolTaxonAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon :adaptee
      
      #
      # Initialize with an Hpricot object of a single Eol XML response
      #
      def initialize(hxml, params = {})
        parser = ::ScientificNameParser.new
        @adaptee = Taxon.new(params)
        @hxml = hxml
        original_name = @hxml.at_xpath('.//dwc:scientificName').inner_text
        if (parsed_name = parser.parse(original_name)) && parsed_name[:scientificName]
          @adaptee.name = parsed_name[:scientificName][:canonical]
        end
        if @adaptee.name.blank?
          raise NameProviderError, "Failed to parse the response from the EOL: #{original_name}"
        end
        @adaptee.rank = @hxml.xpath('.//dwc:taxonRank').map(&:text).inject({}) {|memo,rank| 
          memo[rank] = memo[rank].to_i + 1
          memo
        }.sort_by(&:last).last.try(:first).try(:downcase)
        if @adaptee.rank.blank? && @adaptee.name.split.size == 2
          @adaptee.rank = ::Taxon::SPECIES
        end
        @adaptee.source = EolNameProvider.source
        @adaptee.name_provider = "EolNameProvider"
        @adaptee.source_identifier = begin
          @hxml.at_xpath('.//xmlns:taxonConceptID').try(:text)
        rescue Nokogiri::XML::XPath::SyntaxError => e
          @hxml.at_xpath('.//dwc:taxonConceptID').try(:text)
        end
        @adaptee.source_identifier ||= @hxml.at_xpath('.//dwc:taxonID').try(:text)
        @adaptee.source_url = "http://eol.org/pages/#{@adaptee.source_identifier}"
      end

      def preferred_hierarchy_id
        @hxml.at(".//xmlns:taxon/dwc:taxonID").try(:inner_text)
      end
    end
  end # module NameProviders
end # module Ratatosk

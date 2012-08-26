require 'ratatosk/model_adapter'

module Ratatosk
  module NameProviders
    #
    # Concrete strategy for getting names from the Catalogue of Life
    #
    class ColNameProvider
      def initialize
        @service = CatalogueOfLife.new
      end

      def find(name)
        hxml = @service.search(:name => name, :response => 'full')
        unless hxml.errors.blank?
          raise NameProviderError, "Failed to parse the response from the Catalogue of Life"
        end
        hxml.search('//result').map do |r|
          ColTaxonNameAdapter.new(r)
        end
      end

      #
      # Finds a taxon's ancestors from the name provider and returns an array
      # of them as *new* Taxon objects up until there is one already in our
      # database. Thus, the first Taxon in the array should either be a new
      # Kingdom or an existing saved Taxon that is already in our local tree.
      #
      def get_lineage_for(taxon)
        # If taxon was already fetched with classification data, use that
        if taxon.class != Taxon && taxon.hxml && taxon.hxml.at('classification')
          hxml = taxon.hxml
        else
          hxml = @service.search(:id => taxon.source_identifier, :response => 'full' )
        end
        lineage = [taxon]

        # walk UP the CoL lineage creating new taxa
        [hxml.search('classification/taxon')].flatten.reverse_each do |ancestor_hxml|
          lineage << ColTaxonAdapter.new(ancestor_hxml)
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

    class ColTaxonNameAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon_name :adaptee
      
      #
      # Initialize with an Hpricot object of a single CoL XML response
      #
      def initialize(hxml, params = {})
        @adaptee = TaxonName.new(params)
        @hxml = hxml
        taxon_name.name = @hxml.at('name').inner_text
        taxon_name.lexicon = get_lexicon
        taxon_name.is_valid = get_is_valid
        taxon_name.source = Source.find_by_title('Catalogue of Life')
        taxon_name.source_identifier = @hxml.at('//id').inner_text
        taxon_name.source_url = @hxml.at('url').inner_text
        taxon_name.taxon = taxon
        taxon_name.name_provider = "ColNameProvider"
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

      def get_lexicon
        lex = if @hxml.at_xpath('rank')
          TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
        elsif hxml.at('//language')
          @hxml.at('//language').inner_text.downcase
        else
          nil
        end
        lex == 'unspecified' ? nil : lex
      end

      def get_is_valid
        return true if is_comname?
        ["accepted name", "provisionally accepted name"].include?(@hxml.at_xpath('name_status').inner_text)
      end

      #
      # Test if this is a common / vernacular name
      #
      def is_comname?
        @hxml.at_xpath('rank').nil?
      end

      def get_taxon
        if is_accepted_sciname?
          taxon = ColTaxonAdapter.new(@hxml)
        else
          taxon = ColTaxonAdapter.new(accepted_name_hxml)
        end
        
        # This is necessary because calling save here runs the validations,
        # sees that the Taxon is new and declares the lexion validation ok,
        # then saves the new taxon, which would fire the after save callback
        # creating another taxon name, and then this taxon name gets
        # created, resulting in duplicate, invalid taxon names.
        taxon.skip_new_taxon_name = true
        
        taxon
      end

      def is_accepted_sciname?
        accepted_name.nil?
      end

      def accepted_name
        accepted_name_hxml.at_xpath('name').inner_text rescue nil
      end

      def accepted_name_hxml
        @accepted_name_hxml ||= @hxml.at_xpath('accepted_name')
      end
    end

    class ColTaxonAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon :adaptee
      
      #
      # Initialize with an Hpricot object of a single CoL XML response
      #
      def initialize(hxml, params = {})
        @adaptee = Taxon.new(params)
        @hxml = hxml
        @adaptee.name               = @hxml.at('name').inner_text
        @adaptee.rank               = @hxml.at('rank').inner_text.downcase
        @adaptee.source             = Source.find_by_title('Catalogue of Life')
        @adaptee.source_identifier  = @hxml.at('id').inner_text
        @adaptee.source_url         = @hxml.at('url').inner_text
        @adaptee.name_provider      = "ColNameProvider"
      end
    end
  end # module NameProviders
end # module Ratatosk

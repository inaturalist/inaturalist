require 'ratatosk/model_adapter'

module Ratatosk
  module NameProviders
    #
    # Concrete strategy for getting names from the Catalogue of Life
    #
    class NZORNameProvider
      def initialize
        @service = NewZealandOrganismsRegister.new
      end

      def find(name)
        hxml = @service.search(:query => name)
        unless hxml.errors.blank?
          raise NameProviderError, "Failed to parse the response from the New Zealand Organisms Register"
        end
        hxml.search('//Results').map do |r|
          NZORTaxonNameAdapter.new(r)
        end
      end

      #
      # Finds a taxon's ancestors from the name provider and returns an array
      # of them as *new* Taxon objects up until there is one already in our
      # database. Thus, the first Taxon in the array should either be a new
      # Kingdom or an existing saved Taxon that is already in our local tree.
      #
      def get_lineage_for(taxon)
      end

      # Gets the phylum name for this taxon.
      def get_phylum_for(taxon, lineage = nil)
        binding.pry
      end
    end
    class NZORTaxonNameAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon_name :adaptee
      #
      # Initialize with a Nokogiri object of a single CoL XML response
      #
      def initialize(hxml, params = {})
        @adaptee = TaxonName.new(params)
        @hxml = hxml
        taxon_name.name = @hxml.at('FullName').inner_text
        taxon_name.lexicon = get_lexicon
        taxon_name.is_valid = get_is_valid
        taxon_name.source = Source.find_by_title('New Zealand Organisms Register')
        taxon_name.source_identifier = @hxml.at('NameId').inner_text
        taxon_name.source_url = 'hello' #@hxml.at('url').inner_text
        taxon_name.taxon = taxon
        taxon_name.name_provider = "NZORNameProvider"
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

      #todo, check if it's always Scientific or English, and whether this has an effect'
      def get_lexicon
        if @hxml.at('Class').inner_text == 'Scientific Names'
          'Scientific Name'
        else
          'English'
        end
      end

      #
      # We assume that if the result has an accepted name and that the nameID
      # is equal to the nameID of the actual result then we are valid.
      #
      # TODO confirm that this assumption is correct .. should there only be one result?
      #
      def get_is_valid
        !@hxml.at('Name/AcceptedName/NameId').nil? &&  (@hxml.at('Name/AcceptedName/NameId').inner_text == @hxml.at('Name/NameId').inner_text)
      end

      #
      # Test if this is a common / vernacular name
      # #TODO check if this is a valid assumption
      #
      def is_comname?
        @hxml.at('Class').inner_text == 'Vernacular Name'
      end
      def is_sciname?
        @hxml.at('Class').inner_text == 'Scientific Name'
      end

      def get_taxon
        if is_sciname? and is_valid?
          taxon = NZORTaxonAdapter.new(@hxml)
        else
          taxon = is_comname? ? comname_taxon : sciname_taxon
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
      end

      def accepted_name
      end

      def comname_taxon
      end
      def sciname_taxon
      end
    end
    class NZORTaxonAdapter
      include ModelAdapter
      attr_accessor :hxml
      alias :taxon :adaptee
      #
      # Initialize with a Nokogiri object of a single CoL XML response
      #
      def initialize(hxml, params = {})
        @adaptee = Taxon.new(params)
        @hxml = hxml
        @adaptee.name               = @hxml.at('FullName').inner_text
        @adaptee.rank               = @hxml.at('Rank').inner_text.downcase
        @adaptee.source             = Source.find_by_title('New Zealand Organisms Register')
        @adaptee.source_identifier  = @hxml.at('NameId').inner_text
        @adaptee.source_url         = @hxml.at('NameId').inner_text
        @adaptee.name_provider      = "NZORNameProvider"
      end
    end
  end # module NameProviders
end # module Ratatosk

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
        hxml.search('//result').map do |r|
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
      end
    end
  end # module NameProviders
end # module Ratatosk

require 'ratatosk/model_adapter'

module Ratatosk
  module NameProviders
    #
    # Concrete strategy for getting names from the Catalogue of Life
    #
    class NZORNameProvider
      def initialize
        @service = NewZealandOrganismsRegister.new
        binding.pry
      end

      def find(name)
        hxml = @service.search(:name => name, :response => 'full')
        unless hxml.errors.blank?
          raise NameProviderError, "Failed to parse the response from the Catalogue of Life"
        end
        hxml.search('//result').map do |r|
          NZORTaxonNameAdapter.new(r)
        end
      end
    end
  end # module NameProviders
end # module Ratatosk

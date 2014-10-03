module TaxonDescribers
  class Conabio < Base
    def self.describer_name
      'CONABIO'
    end

    def self.describe(taxon)
      page = conabio_service.search(taxon.name)
      page.blank? ? nil : page
    end

    private
    def conabio_service
      @conabio_service = ConabioService.new
    end
  end
end

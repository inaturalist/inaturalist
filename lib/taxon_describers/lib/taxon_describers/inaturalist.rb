# Trivial taxon describer that uses Taxon#auto_summary to provide a bare bones
# summary of any iNat taxon
module TaxonDescribers
  class Inaturalist < Base
    def describe( taxon )
      taxon.auto_summary
    end

    def page_url( taxon )
      UrlHelper.taxon_url( taxon )
    end

    def name
      "iNaturalist"
    end
    alias :describer_name :name

  end
end

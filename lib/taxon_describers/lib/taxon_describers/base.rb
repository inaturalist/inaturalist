module TaxonDescribers
  class Base

    class_attribute :describer

    def initialize( options = {} )
    end

    def describe(taxon)
      taxon.wikipedia_summary || "No description"
    end
    
    # Not sure how to test a method named "describe" in rspec
    def desc(taxon)
      describe(taxon)
    end

    # Implement in subclasses
    def page_url(taxon)
      nil
    end

    def name
      self.class.name.split( "::" ).last
    end
    alias :describer_name :name

    def self.method_missing(method, *args)
      self.describer = new unless describer.is_a?(self)
      self.describer.send(method, *args)
    end
  end
end

module TaxonDescribers
  class Base
    class_attribute :describer
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

    def self.describer_name
      self.name.split('::').last
    end

    def self.method_missing(method, *args)
      self.describer = new unless describer.is_a?(self)
      self.describer.send(method, *args)
    end

    def fake_view
      FakeView.new(:view_paths => [File.expand_path("../../views/", __FILE__)])
    end
  end
end

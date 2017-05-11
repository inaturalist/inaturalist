require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonPhoto do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }
  describe "destruction" do
    it "should unfeature the taxon if this was the last photo" do
      tp = TaxonPhoto.make!
      t = tp.taxon
      t.update_attributes( featured_at: Time.now )
      t.reload
      expect( t.featured_at ).not_to be_blank
      t.photos = []
      t.reload
      expect( t.featured_at ).to be_blank
    end
  end
end

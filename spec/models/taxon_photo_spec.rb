require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonPhoto do
  describe "destruction" do
    it "should unfeature the taxon if this was the last photo" do
      tp = TaxonPhoto.make
      t = tp.taxon
      t.update_attributes(:featured_at => Time.now)
      t.reload
      t.featured_at.should_not be_blank
      t.photos = []
      t.reload
      t.featured_at.should be_blank
    end
  end
end
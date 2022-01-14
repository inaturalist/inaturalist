require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonPhoto do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to :photo }

  elastic_models( Observation )
  describe "creation" do
    it "should be invalid if there are already the maximum amount of taxon photos" do
      t = Taxon.make!
      TaxonPhoto::MAX_TAXON_PHOTOS.times do
        TaxonPhoto.make!( taxon: t )
      end
      tp = TaxonPhoto.make( taxon: t )
      expect( tp ).not_to be_valid
    end
  end
  describe "destruction" do
    it "should unfeature the taxon if this was the last photo" do
      tp = TaxonPhoto.make!
      t = tp.taxon
      t.update( featured_at: Time.now )
      t.reload
      expect( t.featured_at ).not_to be_blank
      t.photos = []
      t.reload
      expect( t.featured_at ).to be_blank
    end
  end
end

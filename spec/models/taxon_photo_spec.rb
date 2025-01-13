# frozen_string_literal: true

require "spec_helper"

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

  it "flagged taxon photos are removed" do
    taxon_photo = TaxonPhoto.make!
    expect( TaxonPhoto.where( id: taxon_photo.id ).first ).not_to be_nil
    Flag.make!( flaggable: taxon_photo.photo )
    expect( TaxonPhoto.where( id: taxon_photo.id ).first ).to be_nil
  end

  it "cannot be created from flagged photos" do
    photo = Photo.make!
    Flag.make!( flaggable: photo )
    taxon_photo = TaxonPhoto.make( photo: photo )
    expect( taxon_photo ).not_to be_valid
    expect( taxon_photo.errors[:photo] ).not_to be_empty
  end

  describe "indexing" do
    elastic_models( Taxon, TaxonPhoto )
    it "does not index on create" do
      expect_any_instance_of( TaxonPhoto ).not_to receive( :elastic_index! )
      taxon_photo = TaxonPhoto.make!
      expect( TaxonPhoto.elastic_get( taxon_photo.id ) ).to be_blank
    end

    it "does not index on update" do
      taxon_photo = TaxonPhoto.make!
      expect( taxon_photo ).not_to receive( :elastic_index! )
      taxon_photo.update( updated_at: Time.now )
      expect( TaxonPhoto.elastic_get( taxon_photo.id ) ).to be_blank
    end

    it "removes from index on destroy" do
      taxon_photo = TaxonPhoto.make!
      taxon_photo.elastic_index!
      expect( TaxonPhoto.elastic_get( taxon_photo.id ) ).not_to be_blank
      expect( taxon_photo ).to receive( :elastic_delete! ).at_least( :once ).and_call_original
      taxon_photo.destroy
      expect( TaxonPhoto.elastic_get( taxon_photo.id ) ).to be_blank
    end
  end
end

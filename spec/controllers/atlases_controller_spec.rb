require File.dirname(__FILE__) + '/../spec_helper'

describe AtlasesController do
  describe "create" do
    it "should make an atlas belonging to the user" do
      user = User.make!
      atlas = Atlas.make!(user: user)
      expect(atlas.user_id).to eq user.id
    end
  end
  
  describe "alter_atlas_presence" do
    it "should create a listing if one doesn't exist" do
      taxon = Taxon.make!
      place = Place.make!(admin_level: 0)
      user = make_admin
      atlas = Atlas.make!(user: user, taxon: taxon)
      sign_in user
      post :alter_atlas_presence, id: atlas.id, taxon_id: taxon.id, place_id: place.id
      lt = ListedTaxon.where(taxon_id: taxon.id, place_id: place.id, list_id: place.check_list_id).first
      expect(lt).not_to be_blank
    end
    
    it "should destroy a listing if one does exist" do
      taxon = Taxon.make!
      AncestryDenormalizer.denormalize
      place = Place.make!(admin_level: 0)
      check_list = List.find(place.check_list_id)
      check_listed_taxon = check_list.add_taxon(taxon)
      user = make_admin
      atlas = Atlas.make!(user: user, taxon: taxon)
      sign_in user
      post :alter_atlas_presence, id: atlas.id, taxon_id: taxon.id, place_id: place.id
      lt = ListedTaxon.where(taxon_id: taxon.id, place_id: place.id, list_id: place.check_list_id).first
      expect(lt).to be_blank
    end
  end
end

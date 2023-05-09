require "spec_helper"

describe Atlas do
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to :user }
  it { is_expected.to have_many(:exploded_atlas_places).inverse_of(:atlas).dependent :delete_all }
  it { is_expected.to have_many(:atlas_alterations).inverse_of(:atlas).dependent :delete_all }
  it { is_expected.to have_many(:comments).dependent :destroy }

  it { is_expected.to validate_presence_of :taxon }
  it { is_expected.to validate_uniqueness_of(:taxon_id).with_message "already atlased" }

  describe "presence_places" do

    it "should include places from default check lists" do
      atlas = Atlas.make!
      p = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL )
      p.check_list.add_taxon( atlas.taxon )
      expect( atlas.presence_places ).to include p
    end

    it "should not include that are not on default check lists but are on other check lists" do
      atlas = Atlas.make!
      p = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL )
      comprehensive_list = CheckList.make!( place: p, comprehensive: true )
      lt = comprehensive_list.add_taxon( atlas.taxon )
      expect( lt ).to be_valid
      expect( atlas.presence_places ).not_to include p
    end
  end
end

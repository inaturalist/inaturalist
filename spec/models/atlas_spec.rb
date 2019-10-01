# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Atlas, "presence_places" do
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
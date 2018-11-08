# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonCurator, "creation" do
  it "should be valid for framework concept" do
    t = Taxon.make!
    c = Concept.make!( taxon: t, rank_level: Taxon::RANK_LEVELS[Taxon::SUBSPECIES] )
    tc = TaxonCurator.make( concept: c )
    expect( tc ).to be_valid
  end
  it "should not be valid for concept" do
    t = Taxon.make!
    c = Concept.make!( taxon: t, rank_level: nil )
    tc = TaxonCurator.make( concept: c )
    expect( tc ).not_to be_valid
  end
  it "should not be valid for non-curator" do
    t = Taxon.make!
    c = Concept.make!( taxon: t, rank_level: Taxon::RANK_LEVELS[Taxon::SUBSPECIES] )
    u = User.make!
    tc = TaxonCurator.make( concept: c, user: u )
    expect( tc ).not_to be_valid
  end
end

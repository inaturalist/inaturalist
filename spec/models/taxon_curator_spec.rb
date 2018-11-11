# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonCurator, "creation" do
  it "should be valid for taxon framework with coverage" do
    t = Taxon.make!
    tf = TaxonFramework.make!( taxon: t, rank_level: Taxon::RANK_LEVELS[Taxon::SUBSPECIES] )
    tc = TaxonCurator.make( taxon_framework: tf )
    expect( tc ).to be_valid
  end
  it "should not be valid for taxon framework without coverage" do
    t = Taxon.make!
    tf = TaxonFramework.make!( taxon: t, rank_level: nil )
    tc = TaxonCurator.make( taxon_framework: tf )
    expect( tc ).not_to be_valid
  end
  it "should not be valid for non-curator" do
    t = Taxon.make!
    tf = TaxonFramework.make!( taxon: t, rank_level: Taxon::RANK_LEVELS[Taxon::SUBSPECIES] )
    u = User.make!
    tc = TaxonCurator.make( taxon_framework: tf, user: u )
    expect( tc ).not_to be_valid
  end
end

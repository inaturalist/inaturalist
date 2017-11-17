# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonCurator, "creation" do
  it "should be valid for complete taxa" do
    t = Taxon.make!( complete: true )
    tc = TaxonCurator.make( taxon: t )
    expect( tc ).to be_valid
  end
  it "should be valid for a descendant of a complete taxon" do
    genus = Taxon.make!( rank: Taxon::GENUS, complete: true )
    species = Taxon.make!(
      rank: Taxon::SPECIES,
      parent: genus,
      current_user: TaxonCurator.make!( taxon: genus ).user
    )
    tc = TaxonCurator.make( taxon: species )
    expect( tc ).to be_valid
  end
  it "should not be valid for non-complete taxa" do
    t = Taxon.make!( complete: false )
    tc = TaxonCurator.make( taxon: t )
    expect( tc ).not_to be_valid
  end
  it "should not be valid for a descendant of a complete taxon beyond its complete_rank" do
    family = Taxon.make!( complete: true, rank: Taxon::FAMILY, complete_rank: Taxon::GENUS )
    family_curator = TaxonCurator.make!( taxon: family )
    genus = Taxon.make!( rank: Taxon::GENUS, parent: family, current_user: family_curator.user )
    species = Taxon.make!( rank: Taxon::SPECIES, parent: genus, current_user: family_curator.user )
    tc = TaxonCurator.make( taxon: species )
    expect( tc ).not_to be_valid
  end

end

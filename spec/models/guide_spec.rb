# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Guide, "reorder_by_taxon" do
  it "should work" do
    f1 = Taxon.make!(:rank => Taxon::FAMILY)
    f2 = Taxon.make!(:rank => Taxon::FAMILY)
    g1 = Taxon.make!(:rank => Taxon::GENUS, :parent => f1)
    g2 = Taxon.make!(:rank => Taxon::GENUS, :parent => f1)
    g3 = Taxon.make!(:rank => Taxon::GENUS, :parent => f2)
    s1 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g1)
    s2 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g2)
    s3 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g2)
    s4 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g3)
    g = Guide.make!
    gt4 = GuideTaxon.make!(:guide => g, :taxon => s4, :position => 1)
    gt3 = GuideTaxon.make!(:guide => g, :taxon => s3, :position => 2)
    gt2 = GuideTaxon.make!(:guide => g, :taxon => s2, :position => 3)
    gt1 = GuideTaxon.make!(:guide => g, :taxon => s1, :position => 4)
    g.guide_taxa.order(:position).first.should eq(gt4)
    g.reorder_by_taxonomy
    g.reload
    g.guide_taxa.order(:position).first.should eq(gt1)
  end
end

describe Guide, "set_defaults_from_eol_collection" do
  before do
    @guide = Guide.new
    @guide.set_defaults_from_eol_collection("http://eol.org/collections/6970")
  end

  it "should set a title" do
    @guide.title.should_not be_blank
  end

  it "should set a description" do
    @guide.description.should_not be_blank
  end
end

describe Guide, "add_taxa_from_eol_collection" do
  # let(:guide) { Guide.make! }
  let(:eol_collection_url) { "http://eol.org/collections/6970" } 
  it "should add taxa" do
    guide = Guide.make!
    guide.add_taxa_from_eol_collection(eol_collection_url)
    guide.guide_taxa.should_not be_blank
  end
end

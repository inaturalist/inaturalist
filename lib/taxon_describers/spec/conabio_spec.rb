require File.dirname(__FILE__) + '/../../../spec/spec_helper'

describe TaxonDescribers::Conabio do
  before(:all) do
    load_test_taxa
  end
  it "should describe Ursus americanus" do
    t = Taxon.make!(:name => "Ursus americanus", :rank => Taxon::SPECIES)
    x = TaxonDescribers::Conabio.desc(t)
    x.should_not be_blank
  end
end

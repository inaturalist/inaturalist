require File.dirname(__FILE__) + '/../../../spec/spec_helper'

describe TaxonDescribers::AmphibiaWeb do
  before(:all) do
    load_test_taxa
  end
  it "should describe Pseudacris regilla" do
    # TaxonDescribers::AmphibiaWeb.describe(@Calypte_anna).should be_blank
    t = TaxonDescribers::AmphibiaWeb.desc(@Pseudacris_regilla)
    t.should_not be_blank
  end
end

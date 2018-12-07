require File.dirname(__FILE__) + '/../../../spec/spec_helper'

describe TaxonDescribers::Eol do
  before(:all) do
    load_test_taxa
  end
  it "should describe Calypte anna" do
    expect( TaxonDescribers::Eol.desc( @Calypte_anna ) ).not_to be_blank
  end
end

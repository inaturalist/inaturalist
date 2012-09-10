require File.dirname(__FILE__) + '/spec_helper'
require 'name_provider_example_groups'

describe Ratatosk::NameProviders::ColNameProvider do
  it_should_behave_like "a name provider"

  before(:all) do
    @np = Ratatosk::NameProviders::ColNameProvider.new
  end
end

describe Ratatosk::NameProviders::ColTaxonNameAdapter do
  fixtures :sources
  it_should_behave_like "a TaxonName adapter"

  before(:all) do
    @np = Ratatosk::NameProviders::ColNameProvider.new
    @hxml = CatalogueOfLife.new.search(:name => 'Western Bluebird', :response => 'full').at('result')
  end

  before(:each) do
    # make absolutely sure the db is empty
    [TaxonName.find_by_name('Western Bluebird')].flatten.compact.each do |tn|
      tn.destroy
      tn.taxon.destroy if tn.taxon
    end

    @adapter = Ratatosk::NameProviders::ColTaxonNameAdapter.new(@hxml)
  end

  it "should set the taxon of a valid sciname to have the same name" do
    name = "Gerres"
    a = @np.find(name).detect{|n| n.lexicon == TaxonName::LEXICONS[:SCIENTIFIC_NAMES] && n.name == name}
    return unless a
    a.is_valid.should be(true)
    a.taxon.name.should == name
  end

  it "should set the lexicon correctly for 'i'iwi" do
    name = "'i'iwi"
    results = @np.find(name)
    results.select{|tn| tn.name.downcase == name.downcase}.each do |tn|
      tn.lexicon.should_not == TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    end
  end

end

describe Ratatosk::NameProviders::ColTaxonAdapter do
  fixtures :sources
  it_should_behave_like "a Taxon adapter"

  before(:all) do
    @hxml = CatalogueOfLife.new.search(:name => 'Homo sapiens', :response => 'full')
  end

  before(:each) do
    # make absolutely sure the db is empty
    [TaxonName.find(:all, :conditions => "name like 'Homo sapiens%'")].flatten.compact.each do |tn|
      # tn.taxon.destroy
      tn.destroy
    end

    [Taxon.find(:all, :conditions => "name like 'Homo sapiens%'")].flatten.compact.each do |t|
      t.destroy
    end

    @adapter = Ratatosk::NameProviders::ColTaxonAdapter.new(@hxml)
  end
end

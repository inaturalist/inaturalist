require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/name_provider_example_groups'

describe Ratatosk::NameProviders::ColNameProvider do
  it_should_behave_like "a name provider"

  before(:all) do
    load_test_taxa
    @np = Ratatosk::NameProviders::ColNameProvider.new
  end

  it "should return a currently accepted taxon when queried for an invalid synonym" do
    results = @np.find('Hyla crucifer')
    tn = results.first
    t = tn.taxon
    expect(tn).not_to be_is_valid
    expect(t.taxon.name).to eq 'Pseudacris crucifer'
  end

  it "should set the phylum for Periploca ceanothiella to Animalia" do
    expect(Taxon.find_by_name('Periploca ceanothiella')).to be_blank
    results = @np.find('Periploca ceanothiella')
    tn = results.first
    without_delay { tn.save! }
    tn.taxon.graft
    t = tn.taxon
    expect(t).to be_grafted
    expect(t.phylum).not_to be_blank
    expect(t.phylum.name).to eq 'Arthropoda'
  end
end

describe Ratatosk::NameProviders::ColNameProvider, "get_phylum_for" do
  before(:all) do
    load_test_taxa
    @np = Ratatosk::NameProviders::ColNameProvider.new
  end

  it "should set the phylum for Periploca ceanothiella to Animalia" do
    results = @np.find('Periploca ceanothiella')
    tn = results.first
    t = tn.taxon
    phylum = @np.get_phylum_for(t)
    expect(phylum).not_to be_blank
    expect(phylum.name).to eq 'Arthropoda'
  end
end

describe Ratatosk::NameProviders::ColTaxonNameAdapter do
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
    expect(a.is_valid).to be(true)
    expect(a.taxon.name).to eq name
  end

  it "should set the lexicon correctly for iiwi" do
    name = "'i'iwi"
    results = @np.find(name)
    results.select{|tn| tn.name.downcase == name.downcase}.each do |tn|
      expect(tn.lexicon).not_to eq TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
    end
  end

end

describe Ratatosk::NameProviders::ColTaxonAdapter do
  it_should_behave_like "a Taxon adapter"

  before(:all) do
    @hxml = CatalogueOfLife.new.search(:name => 'Homo sapiens', :response => 'full')
  end

  before(:each) do
    # make absolutely sure the db is empty
    TaxonName.where("name like 'Homo sapiens%'").destroy_all
    Taxon.where("name like 'Homo sapiens%'").destroy_all
    @adapter = Ratatosk::NameProviders::ColTaxonAdapter.new(@hxml)
  end
end

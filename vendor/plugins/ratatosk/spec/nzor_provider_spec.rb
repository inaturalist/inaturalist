require File.dirname(__FILE__) + '/spec_helper'
# require File.dirname(__FILE__) + '/../lib/ratatosk/name_providers'

######## Shared Example Groups ##############################################

describe "a name provider", :shared => true do
  
  it "should have a #find method" do
    @np.should respond_to(:find)
  end
  
  it "should have a #get_lineage_for method" do
    pending
    @np.should respond_to(:get_lineage_for)
  end
  
  it "should have a #get_phylum_for method" do
    pending
    @np.should respond_to(:get_phylum_for)
  end
  
  it "should not return more than 10 results by default for #find" do
    pending
    loons = @np.find('loon')
    loons.size.should <= 10
  end
  
  it "should include a TaxonName that EXACTLY matches the query for #find" do
    pending
    taxon_names = @np.find('Pseudacris crucifer')
    taxon_names.map do |tn| 
      tn.name
    end.include?('Pseudacris crucifer').should be(true)
  end
  
  it "should get 'Chordata' as the phylum for 'Homo sapiens'" do
    pending
    taxon = @np.find('Homo sapiens').first.taxon
    phylum = @np.get_phylum_for(taxon)
    phylum.should_not be_nil
    phylum.name.should == 'Chordata'
  end
  
  it "should get 'Magnoliophyta' as the phylum for 'Quercus agrifolia'" do
    pending
    taxon = @np.find('Quercus agrifolia').first.taxon
    phylum = @np.get_phylum_for(taxon)
    phylum.should_not be_nil
    phylum.name.should == 'Magnoliophyta'
  end
  
  it "should get 'Mollusca' as the phylum for 'Hermissenda crassicornis'" do
    pending
    taxon = @np.find('Hermissenda crassicornis').first.taxon
    phylum = @np.get_phylum_for(taxon)
    phylum.should_not be_nil
    phylum.name.should == 'Mollusca'
  end
  
  
  # Some more specific tests. These might seem extraneous, but I find they
  # help find unexpected bugs
  it "should return the parent of 'Thamnophis atratus' as 'Thamnophis', not 'Squamata'" do
    pending
    results = @np.find('Thamnophis atratus')
    that = results.select {|n| n.name == 'Thamnophis atratus'}.first
    lineage = @np.get_lineage_for(that.taxon)
    lineage[1].name.should == 'Thamnophis'
  end
  
  it "should graft 'dragonflies' to a lineage including Odonata" do
    pending
    dflies = @np.find('dragonflies').select {|n| n.name == 'dragonflies'}.first
    unless dflies.nil?
      grafted_lineage = @np.get_lineage_for(dflies.taxon)
      grafted_lineage.map(&:name).include?('Odonata').should be(true)
    end
  end
  
  it "should graft 'roaches' to a lineage including Insecta" do
    pending
    roaches = @np.find('roaches').select {|n| n.name == 'roaches'}.first
    unless roaches.nil?
      grafted_lineage = @np.get_lineage_for(roaches.taxon)
      grafted_lineage.map(&:name).include?('Insecta').should be(true)
    end
  end
end
######## Class Specs ########################################################

describe Ratatosk::NameProviders::NZORNameProvider do
  it_should_behave_like "a name provider"

  before(:all) do
    @np = Ratatosk::NameProviders::NZORNameProvider.new
  end
end

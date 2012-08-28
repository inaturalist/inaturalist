require File.dirname(__FILE__) + '/spec_helper'
# require File.dirname(__FILE__) + '/../lib/ratatosk/name_providers'

######## Shared Example Groups ##############################################

describe "a name provider", :shared => true do
  
  it "should have a #find method" do
    @np.should respond_to(:find)
  end
  
  it "should have a #get_lineage_for method" do
    @np.should respond_to(:get_lineage_for)
  end
  
  it "should have a #get_phylum_for method" do
    @np.should respond_to(:get_phylum_for)
  end
  
  it "should not return more than 10 results by default for #find" do
    loons = @np.find('tree')
    loons.size.should <= 10
  end
  
  it "should include a TaxonName that EXACTLY matches the query for #find" do
    taxon_names = @np.find('Amphioxi')
    taxon_names.map do |tn| 
      tn.name
    end.include?('Amphioxi').should be(true)
  end
  it "should include a TaxonName that has the correct lexicon" do
    taxon_name = @np.find('Amphioxi').first
    taxon_name.lexicon.should == 'Scientific Names'
  end
  
  it "should get 'Chordata' as the phylum for 'Homo sapiens'" do
    taxon = @np.find('Homo sapiens').first.taxon
    phylum = @np.get_phylum_for(taxon)
    #phylum should be a NZORTaxonAdapter
    phylum.should_not be_nil
    phylum.name.should == 'Chordata'
  end
  
  it "should get 'Magnoliophyta' as the phylum for 'Quercus agrifolia'" do
    taxon = @np.find('Quercus agrifolia').first.taxon
    phylum = @np.get_phylum_for(taxon)
    phylum.should_not be_nil
    #TODO NZOR has a different value for this.
# this is what the original was    phylum.name.should == 'Magnoliophyta'
    phylum.name.should == 'Spermatophyta'
  end
  
  it "should get 'Mollusca' as the phylum for 'Paua'" do
    taxon = @np.find('Paua').first.taxon
    phylum = @np.get_phylum_for(taxon)
    phylum.should_not be_nil
    phylum.name.should == 'Mollusca'
  end
  
  
  # Some more specific tests. These might seem extraneous, but I find they
  # help find unexpected bugs
  it "should return the parent of 'Paua' as 'Haliotis'" do
    results = @np.find('Paua')
    that = results.select {|n| n.name == 'Paua'}.first
    lineage = @np.get_lineage_for(that.taxon)
    lineage[1].name.should == 'Haliotis'
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
describe "a Taxon adapter", :shared => true do
  
  it "should have a name" do
    #TODO the partial name is "Homo sapiens"... the full name is "Homo sapiens Linnaeus, 1758"
    #which should it be?
#    @adapter.name.should == 'Homo sapiens'
    @adapter.name.should == 'Homo sapiens'
  end

  it "should return a rank" do
    @adapter.rank.should == 'species'
  end
  
  it "should have a source" do
    @adapter.source.should_not be(nil)
  end
  
  it "should have a source identifier" do
    @adapter.source_identifier.should_not be(nil)
  end
  
  it "should have a source URL" do
    @adapter.source_url.should_not be(nil)
  end
  
  it "should save like a Taxon" do
    Taxon.find_by_name('Homo sapiens').should be(nil)
    a = @adapter.save
    puts "DEBUG: @adapter.errors: #{@adapter.errors.full_messages.join(', ')}" unless @adapter.valid?
    @adapter.new_record?.should_not be(true)
    @adapter.name.should == 'Homo sapiens'
  end
  
  it "should have the same name before and after saving" do
    @adapter.save
    puts "DEBUG: @adapter.errors: #{@adapter.errors.full_messages.join(', ')}" unless @adapter.valid?
    Taxon.find(@adapter.id).name.should == @adapter.name
  end
  
  it "should have a working #to_json method" do
    lambda { @adapter.to_json }.should_not raise_error
  end
  
  it "should only have one scientific name after saving" do
    @adapter.save
    @adapter.reload
    @adapter.taxon_names.select{|n| n.name == @adapter.name}.size.should be(1)
  end
  
  it "should have a unique name after saving" do
    @adapter.save
    @adapter.reload
    @adapter.unique_name.should_not be_nil
  end
end
######## Class Specs ########################################################

describe Ratatosk::NameProviders::NZORNameProvider do
  it_should_behave_like "a name provider"

  before(:all) do
    @np = Ratatosk::NameProviders::NZORNameProvider.new
  end
end
describe Ratatosk::NameProviders::NZORTaxonAdapter do
  fixtures :sources
  it_should_behave_like "a Taxon adapter"
  
  before(:all) do    
    @hxml = NewZealandOrganismsRegister.new.search(:query => 'Homo sapiens')
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
    
    @adapter = Ratatosk::NameProviders::NZORTaxonAdapter.new(@hxml)
  end
end

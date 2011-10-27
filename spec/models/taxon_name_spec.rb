require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonName, 'creation' do
  before(:each) do
    @taxon_name = TaxonName.new(:name => 'Physeter catodon', 
      :is_valid => true, :lexicon => TaxonName::LEXICONS[:SCIENTIFIC_NAMES])
  end
  
  it "should strip the name before validation" do
    tn = TaxonName.new(:name => 'Physeter catodon   ')
    tn.valid?
    tn.name.should == 'Physeter catodon'
  end
  
  it "should captialize scientific names" do
    tn = TaxonName.new(:name => 'physeter catodon', 
      :lexicon => TaxonName::LEXICONS[:SCIENTIFIC_NAMES])
    tn.save
    tn.name.should == 'Physeter catodon'
  end
  
  it "should not capitalize non-scientific names" do
    tn = TaxonName.new(:name => 'sperm whale', 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    tn.save
    tn.name.should == 'sperm whale'
  end
  
  it "should remove leading rank from the name" do
    @taxon_name.name = "Gen Pseudacris"
    @taxon_name.save
    @taxon_name.name.should == 'Pseudacris'
  end
  
  it "should remove internal 'var' from name" do
    @taxon_name.name = "Quercus agrifolia var. agrifolia"
    @taxon_name.save
    @taxon_name.name.should == 'Quercus agrifolia agrifolia'
  end
  
  it "should remove internal 'ssp' from name" do
    @taxon_name.name = "Quercus agrifolia ssp. agrifolia"
    @taxon_name.save
    @taxon_name.name.should == 'Quercus agrifolia agrifolia'
  end
  
  it "should remove internal 'subsp' from name" do
    @taxon_name.name = "Quercus agrifolia subsp. agrifolia"
    @taxon_name.save
    @taxon_name.name.should == 'Quercus agrifolia agrifolia'
  end
  
  it "should not remove hyphens" do
    @taxon_name.name = "Oxalis pes-caprae"
    @taxon_name.save
    @taxon_name.name.should == 'Oxalis pes-caprae'
  end
  
  it "should normalize the lexicon (e.g. capitalize it)" do
    @taxon_name.lexicon = "english"
    @taxon_name.save
    @taxon_name.lexicon.should == TaxonName::LEXICONS[:ENGLISH]
  end
  
  it "should not allow synonyms within a lexicon" do
    taxon = Taxon.make
    name1 = TaxonName.make(:taxon => taxon, :name => "foo", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    name2 = TaxonName.new(:taxon => taxon, :name => "Foo", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    name2.should_not be_valid
  end
  
  it "should strip html" do
    tn = TaxonName.make(:name => "Foo <i>")
    tn.name.should == 'Foo'
  end
end

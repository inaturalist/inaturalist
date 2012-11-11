require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/name_provider_example_groups'

describe Ratatosk::NameProviders::UBioNameProvider do
  it_should_behave_like "a name provider"

  before(:all) do
    @np = Ratatosk::NameProviders::UBioNameProvider.new
  end

  # # This test may start to fail if uBio decides to start showing acceptable
  # # classifications for Medusagyne through their API (they do on the site...)
  # it "should not get a lineage from a rejected classification" do
  #   @np.REJECTED_CLASSIFICATIONS.should include('PreUnion')
  #   medusagyne = @np.find('Medusagyne').first
  #   lambda {@np.get_lineage_for(medusagyne)}.should raise_error(NameProviderError)
  # end

  # it "should find 'Asterias forbesii'" do
  #   tn = @np.find('Asterias forbesii')
  #   tn.should have_at_least(1).taxon_name_adapter
  # end

  it "should not fetch duplicates within the same taxonomicGroup" do
    name = 'Anomaloninae'
    results = @np.find(name)
    results.select {|tn| tn.name == name}.size.should_not > 1
  end

  it "should not make identical taxa for Formica francoeuri"
end

describe Ratatosk::NameProviders::UBioTaxonNameAdapter do
  fixtures :sources
  it_should_behave_like "a TaxonName adapter"

  before(:each) do
    # make absolutely sure the db is empty
    [TaxonName.find_by_name('Western Bluebird')].flatten.compact.each do |tn|
      tn.destroy
      tn.taxon.destroy if tn.taxon
    end

    [Taxon.find(:all, :conditions => "name like 'Western Bluebird%'")].flatten.compact.each do |t|
      t.destroy
    end

    @np = Ratatosk::NameProviders::UBioNameProvider.new
    @adapter = @np.find('Western Bluebird').first
  end
end

describe Ratatosk::NameProviders::UBioTaxonAdapter do
  fixtures :sources
  it_should_behave_like "a Taxon adapter"

  before(:all) do
    @np = Ratatosk::NameProviders::UBioNameProvider.new
    r = @np.service.simple_namebank_search('Homo sapiens')
    @hxml = @np.service.lsid(:namespace => 'namebank',
                            :object => r.first[:namebankID])
  end

  before(:each) do
    # make absolutely sure the db is empty
    [TaxonName.find(:all, :conditions => "name like 'Homo sapiens%'")].flatten.compact.each do |tn|
      tn.destroy
      tn.taxon.destroy if tn.taxon
    end

    [Taxon.find(:all, :conditions => "name like 'Homo sapiens%'")].flatten.compact.each do |t|
      t.destroy
    end

    @adapter = Ratatosk::NameProviders::UBioTaxonAdapter.new(@hxml)
  end

  it "should create a Taxon from a uBio LSID namebank RDF" do
    rdf = @np.service.lsid(:namespace => 'namebank', :object => 2481730)
    rdf.should_not be(nil)
    taxon = Ratatosk::NameProviders::UBioTaxonAdapter.new(rdf)
    taxon.name.should eql("Homo sapiens")
    taxon.rank.should eql("species")
  end

  it "should create a Taxon from a uBio LSID classificationbank RDF" do
    # get the RDF for Homo sapiens in the NCBI Taxonomy classification
    rdf = @np.service.lsid(:namespace => 'classificationbank',
      :object => 2465516)
    taxon = Ratatosk::NameProviders::UBioTaxonAdapter.new(rdf)
    taxon.name.should eql("Homo sapiens")
    taxon.rank.should eql("species")
  end

  it "should set the source_identifier of a Taxon created from a LSID classificationbank RDF to the nambank ID, not the classificationbank ID" do
    rdf = @np.service.lsid(:namespace => 'classificationbank', :object => 1079025)
    taxon = Ratatosk::NameProviders::UBioTaxonAdapter.new(rdf)
    taxon.source_identifier.should_not be_nil
    taxon.source_identifier.should_not == '1079025'

    # this could fail if the classifcationbank -> namebank association is not
    # stable at uBio.  You might want to check
    # http://www.ubio.org/authority/metadata.php?lsid=urn:lsid:ubio.org:classificationbank:1079025
    # for sanity
    taxon.source_identifier.should == '206752'
  end
end

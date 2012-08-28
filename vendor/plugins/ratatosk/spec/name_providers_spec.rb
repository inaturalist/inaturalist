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
    loons = @np.find('loon')
    loons.size.should <= 10
  end

  it "should include a TaxonName that EXACTLY matches the query for #find" do
    taxon_names = @np.find('Pseudacris crucifer')
    taxon_names.map do |tn|
      tn.name
    end.include?('Pseudacris crucifer').should be(true)
  end

  it "should get 'Chordata' as the phylum for 'Homo sapiens'" do
    taxon = @np.find('Homo sapiens').first.taxon
    phylum = @np.get_phylum_for(taxon)
    phylum.should_not be_nil
    phylum.name.should == 'Chordata'
  end

  it "should get 'Magnoliophyta' as the phylum for 'Quercus agrifolia'" do
    taxon = @np.find('Quercus agrifolia').first.taxon
    phylum = @np.get_phylum_for(taxon)
    phylum.should_not be_nil
    phylum.name.should == 'Magnoliophyta'
  end

  it "should get 'Mollusca' as the phylum for 'Hermissenda crassicornis'" do
    taxon = @np.find('Hermissenda crassicornis').first.taxon
    phylum = @np.get_phylum_for(taxon)
    phylum.should_not be_nil
    phylum.name.should == 'Mollusca'
  end


  # Some more specific tests. These might seem extraneous, but I find they
  # help find unexpected bugs
  it "should return the parent of 'Thamnophis atratus' as 'Thamnophis', not 'Squamata'" do
    results = @np.find('Thamnophis atratus')
    that = results.select {|n| n.name == 'Thamnophis atratus'}.first
    lineage = @np.get_lineage_for(that.taxon)
    lineage[1].name.should == 'Thamnophis'
  end

  it "should graft 'dragonflies' to a lineage including Odonata" do
    dflies = @np.find('dragonflies').select {|n| n.name == 'dragonflies'}.first
    unless dflies.nil?
      grafted_lineage = @np.get_lineage_for(dflies.taxon)
      grafted_lineage.map(&:name).include?('Odonata').should be(true)
    end
  end

  it "should graft 'roaches' to a lineage including Insecta" do
    roaches = @np.find('roaches').select {|n| n.name == 'roaches'}.first
    unless roaches.nil?
      grafted_lineage = @np.get_lineage_for(roaches.taxon)
      grafted_lineage.map(&:name).include?('Insecta').should be(true)
    end
  end
end

describe "a Taxon adapter", :shared => true do

  it "should have a name" do
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

describe "a TaxonName adapter", :shared => true do

  it "should return a name" do
    @adapter.name.should == 'Western Bluebird'
  end

  it "should be valid (like all common names)" do
    @adapter.is_valid?.should be(true)
  end

  it "should set the lexicon for 'Western Bluebird' to 'english'" do
    @adapter.lexicon.should == 'english'
  end

  it "should set the lexicon for a scientific name" do
    name = @np.find('Arabis holboellii').first
    name.lexicon.should == TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
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

  it "should set a taxon" do
    @adapter.taxon.should_not be(nil)
    @adapter.taxon.name.should == 'Sialia mexicana'
  end

  it "should have a name_provider set to '#{@np.class.name.split('::').last}" do
    @adapter.name_provider.should == @np.class.name.split('::').last
  end

  it "should save like a TaxonName" do
    puts @adapter.errors.full_messages unless @adapter.valid?
    @adapter.save
    @adapter.reload
    @adapter.new_record?.should be(false)
  end

  it "should be the same before and after saving" do
    @adapter.save
    # puts "DEBUG: @adapter.errors: #{@adapter.errors.full_messages.join(', ')}"
    post = TaxonName.find(@adapter.id)
    %w"name lexicon is_valid source source_identifier source_url taxon name_provider".each do |att|
      post.send(att).should == @adapter.send(att)
    end
  end

  # Note that this can depend on the name provider. For instance, Hyla
  # crucifer would NOT pass this test from uBio as of 2008-06-26
  it "should correctly fill in the is_valid field" do
    bad_name = 'Zigadenus fremontii'
    a = @np.find(bad_name)
    taxon_name = a.detect {|n| n.name == bad_name}
    taxon_name.name.should == bad_name
    # puts "taxon_name.hxml: #{taxon_name.hxml}"
    taxon_name.is_valid.should be(false)
  end

  it "should always set is_valid to true for single sci names" do
    name = "Geum triflorum"
    a = @np.find(name)
    taxon_name = a.select {|n| n.name == name}.first
    taxon_name.name.should == name
    taxon_name.is_valid.should be(true)
  end

  it "should have a working #to_json method" do
    lambda { @adapter.to_json }.should_not raise_error
  end

end


######## Class Specs ########################################################

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

describe Ratatosk::NameProviders::UBioNameProvider do
  # it_should_behave_like "a name provider"

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

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
    loons = @np.find('Sceloporus')
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

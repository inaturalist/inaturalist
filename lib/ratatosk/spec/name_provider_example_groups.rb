shared_examples_for "a name provider" do
  it "should have a #find method" do
    expect(@np).to respond_to(:find)
  end

  it "should have a #get_lineage_for method" do
    expect(@np).to respond_to(:get_lineage_for)
  end

  it "should have a #get_phylum_for method" do
    expect(@np).to respond_to(:get_phylum_for)
  end

  it "should not return more than 10 results by default for #find" do
    loons = @np.find('Sceloporus')
    expect(loons.size).to be <= 10
  end

  it "should include a TaxonName that EXACTLY matches the query for #find" do
    taxon_names = @np.find('Pseudacris crucifer')
    expect( taxon_names.map {|tn| tn.name} ).to include('Pseudacris crucifer')
  end

  # The following two specs presume a lot about the classifications used by
  # the external provider, and they were failing with the EOL Name Provider
  # They should probably be replaced with tests that look at how taxa from the
  # name provider graft to an existing tree
  
  # it "should get 'Chordata' as the phylum for 'Homo sapiens'" do
  #   mammalia = Taxon.make!(:name => "Mammalia", :rank => Taxon::ORDER, :parent => @Chordata)
  #   taxon = @np.find('Homo sapiens').detect{|tn| tn.name == 'Homo sapiens'}.taxon
  #   puts "taxon.hxml: #{taxon.hxml}"
  #   phylum = @np.get_phylum_for(taxon)
  #   expect(phylum).not_to be_nil
  #   expect(phylum.name).to eq 'Chordata'
  # end
  # it "should get 'Magnoliophyta' as the phylum for 'Quercus agrifolia'" do
  #   fagales = Taxon.make!(:name => "Fagales", :rank => Taxon::ORDER, :parent => @Magnoliopsida)
  #   taxon = @np.find('Quercus agrifolia').first.taxon
  #   phylum = @np.get_phylum_for(taxon)
  #   expect(phylum).not_to be_nil
  #   expect(phylum.name).to eq 'Magnoliophyta'
  # end

  it "should get 'Mollusca' as the phylum for 'Hermissenda crassicornis'" do
    taxon = @np.find('Hermissenda crassicornis').first.taxon
    phylum = @np.get_phylum_for(taxon)
    expect(phylum).not_to be_nil
    expect(phylum.name).to eq 'Mollusca'
  end


  # Some more specific tests. These might seem extraneous, but I find they
  # help find unexpected bugs
  it "should return the parent of 'Thamnophis atratus' as 'Thamnophis', not 'Squamata'" do
    results = @np.find('Thamnophis atratus')
    that = results.select {|n| n.name == 'Thamnophis atratus'}.first
    lineage = @np.get_lineage_for(that.taxon)
    expect(lineage[1].name).to eq 'Thamnophis'
  end

  it "should graft 'dragonflies' to a lineage including Odonata" do
    dflies = @np.find('dragonflies').select {|n| n.name.downcase == 'dragonflies'}.first
    unless dflies.nil?
      grafted_lineage = @np.get_lineage_for(dflies.taxon)
      expect( grafted_lineage.map(&:name) ).to include('Odonata')
    end
  end

  it "should graft 'roaches' to a lineage including Insecta" do
    roaches = @np.find('roaches').select {|n| n.name == 'roaches'}.first
    unless roaches.nil?
      grafted_lineage = @np.get_lineage_for(roaches.taxon)
      expect( grafted_lineage.map(&:name) ).to include('Insecta')
    end
  end
end

shared_examples_for "a Taxon adapter" do

  it "should have a name" do
    expect(@adapter.name).to eq 'Homo sapiens'
  end

  it "should return a rank" do
    expect(@adapter.rank).to eq 'species'
  end

  it "should have a source" do
    expect(@adapter.source).not_to be(nil)
  end

  it "should have a source identifier" do
    expect(@adapter.source_identifier).not_to be(nil)
  end

  it "should have a source URL" do
    expect(@adapter.source_url).not_to be(nil)
  end

  it "should save like a Taxon" do
    expect(Taxon.find_by_name('Homo sapiens')).to be(nil)
    a = @adapter.save
    puts "DEBUG: @adapter.errors: #{@adapter.errors.full_messages.join(', ')}" unless @adapter.valid?
    expect(@adapter.new_record?).not_to be(true)
    expect(@adapter.name).to eq 'Homo sapiens'
  end

  it "should have the same name before and after saving" do
    @adapter.save
    puts "DEBUG: @adapter.errors: #{@adapter.errors.full_messages.join(', ')}" unless @adapter.valid?
    expect(Taxon.find(@adapter.id).name).to eq @adapter.name
  end

  it "should have a working #to_json method" do
    expect { @adapter.to_json }.not_to raise_error
  end

  it "should only have one scientific name after saving" do
    @adapter.save
    @adapter.reload
    expect(@adapter.taxon_names.select{|n| n.name == @adapter.name}.size).to be(1)
  end

  it "should have a unique name after saving" do
    @adapter.save
    @adapter.reload
    expect(@adapter.unique_name).not_to be_nil
  end
end

shared_examples_for "a TaxonName adapter" do

  it "should return a name" do
    expect(@adapter.name).to eq 'Western Bluebird'
  end

  it "should be valid (like all common names)" do
    expect(@adapter.is_valid?).to be(true)
  end

  it "should set the lexicon for 'Western Bluebird' to 'English'" do
    expect(@adapter.lexicon).to eq "English"
  end

  it "should set the lexicon for a scientific name" do
    name = @np.find('Arabis holboellii').first
    expect(name.lexicon).to eq TaxonName::LEXICONS[:SCIENTIFIC_NAMES]
  end

  it "should have a source" do
    expect(@adapter.source).not_to be(nil)
  end

  it "should have a source identifier" do
    expect(@adapter.source_identifier).not_to be(nil)
  end

  it "should have a source URL" do
    expect(@adapter.source_url).not_to be(nil)
  end

  it "should set a taxon" do
    expect(@adapter.taxon).not_to be(nil)
    expect(@adapter.taxon.name).to eq 'Sialia mexicana'
  end

  it "should have a name_provider set to '#{@np.class.name.split('::').last}" do
    expect(@adapter.name_provider).to eq @np.class.name.split('::').last
  end

  it "should save like a TaxonName" do
    puts @adapter.errors.full_messages unless @adapter.valid?
    @adapter.save
    @adapter.reload
    expect(@adapter.new_record?).to be(false)
  end

  it "should be the same before and after saving" do
    @adapter.save!
    # puts "DEBUG: @adapter.errors: #{@adapter.errors.full_messages.join(', ')}"
    post = TaxonName.find(@adapter.id)
    %w"name lexicon is_valid source_id source_identifier source_url taxon name_provider".each do |att|
      expect(post.send(att)).to eq @adapter.send(att)
    end
  end

  # Note that this can depend on the name provider. For instance, Hyla
  # crucifer would NOT pass this test from uBio as of 2008-06-26
  it "should correctly fill in the is_valid field" do
    bad_name = 'Zigadenus fremontii'
    a = @np.find(bad_name)
    taxon_name = a.detect {|n| n.name == bad_name}
    expect(taxon_name).not_to be_blank
    expect(taxon_name.name).to eq bad_name
    # puts "taxon_name.hxml: #{taxon_name.hxml}"
    expect(taxon_name).not_to be_is_valid
  end

  it "should always set is_valid to true for single sci names" do
    name = "Geum triflorum"
    a = @np.find(name)
    taxon_name = a.select {|n| n.name == name}.first
    expect(taxon_name.name).to eq name
    expect(taxon_name.is_valid).to be(true)
  end

  it "should have a working #to_json method" do
    expect { @adapter.to_json }.not_to raise_error
  end
end

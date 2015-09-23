require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/name_provider_example_groups'

describe Ratatosk::NameProviders::EolNameProvider do
  it_should_behave_like "a name provider"

  before(:all) do
    load_test_taxa
    @np = Ratatosk::NameProviders::EolNameProvider.new
  end

  it "should set the source_identifier of Epimartyria pardella to 965114" do
    taxon_name = @np.find('Epimartyria pardella').first
    expect( taxon_name.taxon.source_identifier ).to eq '965114'
  end

  it "should find invalid names" do
    results = @np.find('Hyla crucifer')
    taxon_name = results.detect{|tn| tn.name == 'Hyla crucifer'}
    expect( taxon_name ).not_to be_blank
  end

  it "should attach invalid names to a valid taxon" do
    results = @np.find('Hyla crucifer')
    taxon_name = results.detect{|tn| tn.name == 'Hyla crucifer'}
    expect( taxon_name.taxon.name ).to eq 'Pseudacris crucifer'
  end

  it "should find taxa by common name" do
    results = @np.find('American Alligator')
    taxon_name = results.detect{|tn| tn.name == 'Alligator mississippiensis'}
    expect( taxon_name ).not_to be_blank
    expect( taxon_name.taxon.name ).to eq 'Alligator mississippiensis'
  end

  it "should return a taxon name for common names" do
    results = @np.find('American Alligator')
    taxon_name = results.detect{|tn| tn.name.downcase == 'american alligator'}
    expect( taxon_name ).not_to be_blank
    expect( taxon_name.lexicon ).to eq 'english'
  end

  it "should graft" do
    results = @np.find('American Alligator')
    tn = results.detect{|tn| tn.name.downcase == 'american alligator'}
    tn.save!
    t = Taxon.find_by_id(tn.taxon_id)
    t.graft
    expect( t ).to be_grafted
  end

  it "should find a bunch of names" do
    names = [
      'Ofatulena duodecemstriata',
      'Acossus populi'
    ]
    names.each do |name|
      results = @np.find(name)
      expect( results ).not_to be_blank
      expect( results.first.name ).to eq name
      expect( results.first.taxon.name ).to eq name
      expect( results.first.taxon.rank ).to eq Taxon::SPECIES
      unless results.first.taxon.valid?
        puts "taxon errors: #{results.first.taxon.errors.full_messages.to_sentence}"
      end
      expect( results.first.taxon ).to be_valid
    end
  end

end

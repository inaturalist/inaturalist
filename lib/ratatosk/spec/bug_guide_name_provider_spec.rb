require File.dirname(__FILE__) + '/spec_helper'

describe Ratatosk::NameProviders::BugGuideNameProvider do
  let(:np) { Ratatosk::NameProviders::BugGuideNameProvider.new }
  it "should find a taxon" do
    name = 'Apis mellifera'
    expect( np.find(name).first.name ).to eq name
  end

  it "should get a lineage including Insecta" do
    name = 'Apis mellifera'
    t = np.find(name).first.taxon
    expect( np.get_lineage_for(t).map(&:name) ).to include 'Insecta'
  end

  it "should set the phylum for everything to Arthropoda" do
    name = 'Idia americalis'
    t = np.find(name).first.taxon
    expect( np.get_phylum_for(t).name ).to eq 'Arthropoda'
  end

  describe "get_lineage_for" do
    let(:t) { np.find('Apis mellifera').first.taxon }
    it "should have the target taxon as the first in the lineage" do
      expect( np.get_lineage_for(t).first ).to eq t
    end
    it "should contain taxa that increase in rank_level" do
      ancestor_levels = np.get_lineage_for(t).map(&:rank_level).compact
      expect( ancestor_levels.sort ).to eq ancestor_levels
    end
  end

  it "should graft" do
    animalia = Taxon.make!(name: 'Animalia', rank: Taxon::KINGDOM, is_iconic: true)
    arthropoda = Taxon.make!(name: 'Arthropoda', rank: Taxon::PHYLUM)
    name = 'Idia americalis'
    t = np.find(name).first.taxon
    t.save!
    t.reload
    t.graft
    t.reload
    expect( t ).to be_grafted
  end

end

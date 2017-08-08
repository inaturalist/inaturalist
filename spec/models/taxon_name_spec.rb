# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonName, 'creation' do
  before(:each) do
    @taxon_name = TaxonName.new(:name => 'Physeter catodon', 
      :is_valid => true, :lexicon => TaxonName::LEXICONS[:SCIENTIFIC_NAMES])
  end
  
  it "should strip the name before validation" do
    tn = TaxonName.new(:name => 'Physeter catodon   ')
    tn.valid?
    expect(tn.name).to eq 'Physeter catodon'
  end
  
  it "should captialize scientific names" do
    tn = TaxonName.new(:name => 'physeter catodon', 
      :lexicon => TaxonName::LEXICONS[:SCIENTIFIC_NAMES])
    tn.save
    expect(tn.name).to eq 'Physeter catodon'
  end
  
  it "should not capitalize non-scientific names" do
    tn = TaxonName.new(:name => 'sperm whale', 
      :lexicon => TaxonName::LEXICONS[:ENGLISH])
    tn.save
    expect(tn.name).to eq 'sperm whale'
  end
  
  it "should remove leading rank from the name" do
    @taxon_name.name = "Gen Pseudacris"
    @taxon_name.save
    expect(@taxon_name.name).to eq 'Pseudacris'
  end
  
  it "should remove internal 'var' from name" do
    @taxon_name.name = "Quercus agrifolia var. agrifolia"
    @taxon_name.save
    expect(@taxon_name.name).to eq 'Quercus agrifolia agrifolia'
  end
  
  it "should remove internal 'ssp' from name" do
    @taxon_name.name = "Quercus agrifolia ssp. agrifolia"
    @taxon_name.save
    expect(@taxon_name.name).to eq 'Quercus agrifolia agrifolia'
  end
  
  it "should remove internal 'subsp' from name" do
    @taxon_name.name = "Quercus agrifolia subsp. agrifolia"
    @taxon_name.save
    expect(@taxon_name.name).to eq 'Quercus agrifolia agrifolia'
  end
  
  it "should not remove hyphens" do
    @taxon_name.name = "Oxalis pes-caprae"
    @taxon_name.save
    expect(@taxon_name.name).to eq 'Oxalis pes-caprae'
  end
  
  it "should normalize the lexicon (e.g. capitalize it)" do
    @taxon_name.lexicon = "english"
    @taxon_name.save
    expect(@taxon_name.lexicon).to eq TaxonName::LEXICONS[:ENGLISH]
  end
  
  it "should not allow synonyms within a lexicon" do
    taxon = Taxon.make!
    name1 = TaxonName.make!(:taxon => taxon, :name => "foo", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    name2 = TaxonName.new(:taxon => taxon, :name => "Foo", :lexicon => TaxonName::LEXICONS[:ENGLISH])
    expect(name2).not_to be_valid
  end
  
  it "should strip html" do
    tn = TaxonName.make!(:name => "Foo <i>")
    expect(tn.name).to eq 'Foo'
  end

  it "should set is_valid to true for common names by default" do
    tn = TaxonName.make!(:lexicon => TaxonName::LEXICONS[:ENGLISH])
    expect(tn.is_valid).to be true
  end

  it "should not set is_valid to true for common names if it was set to false" do
    tn = TaxonName.make!(:lexicon => TaxonName::LEXICONS[:ENGLISH], :is_valid => false)
    expect(tn.is_valid).to be false
  end
    
  it "should create new name positions that will place them at the end of lists" do
    t = Taxon.make!
    tn1 = TaxonName.make!(name: "first", taxon: t)
    expect(tn1.position).to eq 1
    tn2 = TaxonName.make!(name: "second", taxon: t)
    expect(tn2.position).to eq 2
    tn2 = TaxonName.make!(name: "third", taxon: t)
    expect(tn2.position).to eq 3
  end
end

describe TaxonName, "strip_author" do
  it "should work" do
    [
      ["Larix kaempferi", "Larix kaempferi (Lamb.) Carriére"],
      ["Libocedrus bidwillii", "Libocedrus bidwillii Hook. f."],
      ["Macrozamia conferta", "Macrozamia conferta D. L. Jones & P. I. Forst."],
      ["Macrozamia dyeri", "Macrozamia dyeri (F. Muell.) C. A. Gardner"],
      ["Dacrydium gracile", "Dacrydium gracile de Laub."],
      ["Polystichum minimum", "Polystichum minimum (Y.T.Hsieh) comb. ined."],
      ["Stelis macrophylla", "Stelis macrophylla (Kunth) ined."],
      ["Bromheadia finlaysoniana", "Bromheadia finlaysoniana (Lindl.) & Miq."],
      ["Pleopeltis pleopeltidis", "Pleopeltis pleopeltidis (Fée) de la Sota"],
      ["Oncidium schunkeanum", "Oncidium schunkeanum Campacci & Cath."],
      ["Astragalus albispinus esfandiarii", "Astragalus albispinus esfandiarii"]
    ].each do |stripped, name|
      expect(TaxonName.strip_author(name)).to eq stripped
    end
  end
end

describe TaxonName, "choose_common_name" do
  let(:t) { Taxon.make! }
  it "should not choose an invalid common name" do
    tn_invalid = TaxonName.make!(:is_valid => false, :taxon => t, :lexicon => "English", :name => "Bar")
    tn_valid = TaxonName.make!(:is_valid => true, :taxon => t, :lexicon => "English", :name => "Foo")
    expect(TaxonName.choose_common_name([tn_invalid, tn_valid])).to eq tn_valid
  end

  it "should choose a locale-specific name" do
    tn_en = TaxonName.make!(:name => "snail", :lexicon => "English", :taxon => t)
    tn_es = TaxonName.make!(:name => "caracol", :lexicon => "Spanish", :taxon => t)
    expect(TaxonName.choose_common_name([tn_en, tn_es], :locale => :es)).to eq tn_es
  end

  it "should not choose a non-locale-specific name" do
    tn_en = TaxonName.make!(name: "snail", lexicon: "English", taxon: t)
    expect( TaxonName.choose_common_name(tn_en.taxon.taxon_names, locale: :es) ).to be_blank
  end

  it "should choose a locale=specific name for traditional Chinese" do
    tn_en = TaxonName.make!(:name => "Queen's Wreath", :lexicon => "English", :taxon => t)
    tn_zh_tw = TaxonName.make!(:name => "藍花藤", :lexicon => "Chinese (traditional)", :taxon => t)
    expect(TaxonName.choose_common_name([tn_en, tn_zh_tw], :locale => "zh-TW")).to eq tn_zh_tw
  end

  it "should choose a locale=specific name for simplified Chinese" do
    tn_en = TaxonName.make!(:name => "Queen's Wreath", :lexicon => "English", :taxon => t)
    tn_zh_cn = TaxonName.make!(:name => "藍花藤", :lexicon => "Chinese (simplified)", :taxon => t)
    expect(TaxonName.choose_common_name([tn_en, tn_zh_cn], :locale => "zh-CN")).to eq tn_zh_cn
  end

  it "should choose a place-specific name" do
    california = Place.make!
    oregon = Place.make!
    tn_gl = TaxonName.make!(:name => "bay tree", :lexicon => "English", :taxon => t)
    tn_ca = TaxonName.make!(:name => "California bay laurel", :lexicon => "English", :taxon => t)
    ptn_ca = PlaceTaxonName.make!(:taxon_name => tn_ca, :place => california)
    tn_or = TaxonName.make!(:name => "Oregon myrtle", :lexicon => "English", :taxon => t)
    ptn_or = PlaceTaxonName.make!(:taxon_name => tn_or, :place => oregon)
    t.reload
    expect(TaxonName.choose_common_name(t.taxon_names, :place => oregon)).to eq tn_or
    expect(TaxonName.choose_common_name(t.taxon_names, :place => california)).to eq tn_ca
    expect(TaxonName.choose_common_name(t.taxon_names)).to eq tn_gl
  end
  it "should choose a place-specific name regardless of locale" do
    california = Place.make!
    oregon = Place.make!
    tn_gl = TaxonName.make!(:name => "bay tree", :lexicon => "English", :taxon => t)
    tn_es = TaxonName.make!(:name => "Laurel de California", :lexicon => "Spanish", :taxon => t)
    # ptn_ca = PlaceTaxonName.make!(:taxon_name => tn_ca, :place => california)
    tn_or = TaxonName.make!(:name => "Oregon myrtle", :lexicon => "English", :taxon => t)
    ptn_or = PlaceTaxonName.make!(:taxon_name => tn_or, :place => oregon)
    t.reload
    expect(TaxonName.choose_common_name(t.taxon_names, :place => oregon, :locale => :es)).to eq tn_or
  end

  it "should pick a place-specific name for a parent of the requested place" do
    california = Place.make!
    oregon = Place.make!
    tn_gl = TaxonName.make!(:name => "bay tree", :lexicon => "English", :taxon => t)
    tn_ca = TaxonName.make!(:name => "California bay laurel", :lexicon => "English", :taxon => t)
    ptn_ca = PlaceTaxonName.make!(:taxon_name => tn_ca, :place => california)
    t.reload
    p = Place.make!(:parent => california, :name => "Alameda County")
    expect(p.self_and_ancestor_ids).to include(california.id)
    expect(TaxonName.choose_common_name(t.taxon_names, :place => p)).to eq tn_ca
    expect(TaxonName.choose_common_name(t.taxon_names)).to eq tn_gl
  end

  it "should pick names based on the site's place" do
    california = Place.make!
    oregon = Place.make!
    tn_gl = TaxonName.make!(name: "bay tree", lexicon: "English", taxon: t)
    tn_es = TaxonName.make!(name: "Laurel de California", lexicon: "Spanish", taxon: t)
    tn_or = TaxonName.make!(name: "Oregon myrtle", lexicon: "English", taxon: t)
    ptn_or = PlaceTaxonName.make!(taxon_name: tn_or, place: oregon)
    t.reload
    Site.default.update_attributes( place: oregon )
    expect(TaxonName.choose_common_name( t.taxon_names, site: Site.default ) ).to eq tn_or
  end
end

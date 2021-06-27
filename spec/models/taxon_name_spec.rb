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
  
  it "should not allow synonyms within a parameterized lexicon" do
    taxon = Taxon.make!
    _name1 = TaxonName.make!(:taxon => taxon, :name => "foo", :lexicon => TaxonName::LEXICONS[:CHINESE_SIMPLIFIED])
    name2 = TaxonName.new(:taxon => taxon, :name => "Foo", :lexicon => TaxonName::LEXICONS[:CHINESE_SIMPLIFIED].upcase)
    expect(name2).not_to be_valid
  end
  
  it "should strip html" do
    tn = TaxonName.make!(:name => "Foo <i>")
    expect(tn.name).to eq 'Foo'
  end

  it "should strip the lexicon" do
    expect( TaxonName.make!( lexicon: " Foo" ).lexicon ).to eq "Foo"
  end

  it "should not be valid with a non-English translation of a lexicon" do
    tn = TaxonName.make(lexicon: I18n.with_locale(:"zh-CN") { I18n.t("lexicons.finnish") }, name: "common")
    expect(tn).to_not be_valid
    expect(tn.errors.messages[:lexicon]).to include(
      I18n.t("activerecord.errors.models.taxon_name.attributes.lexicon.should_match_english_translation", 
             suggested: I18n.with_locale(:en) { I18n.t("lexicons.finnish") }, 
             suggested_locale: I18n.t("locales.zh-CN")
      )
    )
  end
  
  it "should parameterize and store lexicon" do
    tn = TaxonName.make!(lexicon: TaxonName::LEXICONS[:CHINESE_SIMPLIFIED], name: "common")
    expect(tn.parameterized_lexicon).to eq "chinese-simplified"
  end
  
  it "should not parameterize and store lexicon with invalid characters" do
    tn = TaxonName.make(lexicon: "测试", name: "common")
    expect(tn).to_not be_valid
    expect(tn.errors.messages[:lexicon]).to include(
      I18n.t("activerecord.errors.models.taxon_name.attributes.lexicon.should_be_in_english")
    )
  end
  
  it "should not validate presence of a parameterizable lexicon if lexicon not present" do
    tn = TaxonName.make(lexicon: nil, name: "common")
    expect(tn).to be_valid
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
    tn3 = TaxonName.make!(name: "third", taxon: t)
    expect(tn3.position).to eq 3
  end

  it "should not allow species names that match the taxon name that are non-scientific" do
    t = Taxon.make!( rank: Taxon::SPECIES, name: "Foo bar" )
    tn = TaxonName.make( taxon: t, lexicon: TaxonName::LEXICONS[:ENGLISH], name: t.name )
    expect( tn ).not_to be_valid
    expect( tn.errors[:name] ).not_to be_blank
  end

  it "should not allow two valid scientific names per taxon" do
    t = Taxon.make!
    tn1 = t.taxon_names.where( lexicon: TaxonName::LEXICONS[:SCIENTIFIC_NAMES] ).first
    expect( tn1 ).to be_is_valid
    tn2 = TaxonName.make( taxon: t, lexicon: TaxonName::LEXICONS[:SCIENTIFIC_NAMES], is_valid: true )
    expect( tn2 ).not_to be_valid
    puts "errors: #{tn2.errors.full_messages.to_sentence}"
    expect( tn2.errors[:name] ).not_to be_blank
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
    expect(TaxonName.choose_common_name([tn_invalid, tn_valid], locale: :en) ).to eq tn_valid
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

  it "should choose a locale-specific name for traditional Chinese" do
    tn_en = TaxonName.make!(:name => "Queen's Wreath", :lexicon => "English", :taxon => t)
    tn_zh_tw = TaxonName.make!(:name => "藍花藤", :lexicon => "Chinese (traditional)", :taxon => t)
    expect(TaxonName.choose_common_name([tn_en, tn_zh_tw], :locale => "zh-TW")).to eq tn_zh_tw
  end

  it "should choose a locale-specific name for simplified Chinese" do
    tn_en = TaxonName.make!(:name => "Queen's Wreath", :lexicon => "English", :taxon => t)
    tn_zh_cn = TaxonName.make!(:name => "藍花藤", :lexicon => "Chinese (simplified)", :taxon => t)
    expect(TaxonName.choose_common_name([tn_en, tn_zh_cn], :locale => "zh-CN")).to eq tn_zh_cn
  end

  it "should choose a Norwegian name for a Bokmal locale" do
    tn_norwegian = TaxonName.make!( lexicon: "Norwegian" )
    tn_bokmal = TaxonName.make!( lexicon: "Norwegian Bokmal" )
    expect( TaxonName.choose_common_name( [tn_norwegian, tn_bokmal], locale: "nb" ) ).to eq tn_norwegian
  end

  it "should respect position when choosing a locale-specific name" do
    tn_romanji = TaxonName.make!( name: "Hamachi", lexicon: "Japanese", taxon: t )
    tn_ja = TaxonName.make!( name: "ブリ", lexicon: "Japanese", taxon: t )
    tn_ja.update_attributes( position: 1 )
    tn_romanji.update_attributes( position: 2 )
    expect( TaxonName.choose_common_name( [tn_romanji, tn_ja], locale: "ja" ) ).to eq tn_ja
  end

  it "should choose a locale-specific place-specific name" do
    california = make_place_with_geom
    oregon = make_place_with_geom
    tn_en = TaxonName.make!(:name => "bay tree", :lexicon => "English", :taxon => t)
    tn_ca = TaxonName.make!(:name => "California bay laurel", :lexicon => "English", :taxon => t)
    ptn_ca = PlaceTaxonName.make!(:taxon_name => tn_ca, :place => california)
    tn_or = TaxonName.make!(:name => "Oregon myrtle", :lexicon => "English", :taxon => t)
    ptn_or = PlaceTaxonName.make!(:taxon_name => tn_or, :place => oregon)
    t.reload
    expect( TaxonName.choose_common_name( t.taxon_names, place: oregon ) ).to eq tn_or
    expect( TaxonName.choose_common_name( t.taxon_names, place: california ) ).to eq tn_ca
    expect( TaxonName.choose_common_name( t.taxon_names, locale: :en ) ).to eq tn_en
  end

  it "should pick a locale-specific place-specific name for a parent of the requested place" do
    california = make_place_with_geom
    oregon = make_place_with_geom
    tn_en = TaxonName.make!(:name => "bay tree", :lexicon => "English", :taxon => t)
    tn_ca = TaxonName.make!(:name => "California bay laurel", :lexicon => "English", :taxon => t)
    ptn_ca = PlaceTaxonName.make!(:taxon_name => tn_ca, :place => california)
    t.reload
    p = make_place_with_geom(:parent => california, :name => "Alameda County")
    expect(p.self_and_ancestor_ids).to include(california.id)
    expect(TaxonName.choose_common_name(t.taxon_names, :place => p)).to eq tn_ca
    expect(TaxonName.choose_common_name(t.taxon_names)).to eq tn_en
  end

  it "should pick names based on the site's place" do
    california = make_place_with_geom
    oregon = make_place_with_geom
    tn_en = TaxonName.make!(name: "bay tree", lexicon: "English", taxon: t)
    tn_es = TaxonName.make!(name: "Laurel de California", lexicon: "Spanish", taxon: t)
    tn_or = TaxonName.make!(name: "Oregon myrtle", lexicon: "English", taxon: t)
    ptn_or = PlaceTaxonName.make!(taxon_name: tn_or, place: oregon)
    t.reload
    Site.default.update_attributes( place: oregon )
    expect(TaxonName.choose_common_name( t.taxon_names, site: Site.default ) ).to eq tn_or
  end

  it "should favor a locale within a place" do
    p = make_place_with_geom
    tn_en = TaxonName.make!( name: "bay tree", lexicon: "English", taxon: t )
    tn_es = TaxonName.make!( name: "Laurel de California", lexicon: "Spanish", taxon: t )
    ptn_tn_en = PlaceTaxonName.make!( taxon_name: tn_en, place: p, position: 1 )
    ptn_tn_es = PlaceTaxonName.make!( taxon_name: tn_es, place: p, position: 2 )
    t.reload
    expect( TaxonName.choose_common_name( t.taxon_names, place: p, locale: "es" ) ).to eq tn_es
  end

  it "should not pick a name if it doesn't match the locale even if it matches an ancestor place" do
    ancestor_place = make_place_with_geom
    place = make_place_with_geom( parent: ancestor_place )
    tn_en = TaxonName.make!( name: "bay tree", lexicon: "English", taxon: t )
    tn_es = TaxonName.make!( name: "Laurel de California", lexicon: "Spanish", taxon: t )
    ptn_tn_en = PlaceTaxonName.make!( taxon_name: tn_en, place: ancestor_place, position: 1 )
    ptn_tn_es = PlaceTaxonName.make!( taxon_name: tn_es, place: ancestor_place, position: 2 )
    t.reload
    expect( TaxonName.choose_common_name( t.taxon_names, place: place, locale: "ja" ) ).to be_blank
  end

  it "should pick a name if it doesn't match the locale if it exactly matches a place" do
    place = make_place_with_geom
    tn_en = TaxonName.make!( name: "bay tree", lexicon: "English", taxon: t )
    ptn_tn_en = PlaceTaxonName.make!( taxon_name: tn_en, place: place, position: 1 )
    t.reload
    expect( TaxonName.choose_common_name( t.taxon_names, place: place, locale: "ja" ) ).to eq tn_en
  end
end

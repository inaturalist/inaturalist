# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe GuideTaxon, "creation" do
  before(:all) do
    load_test_taxa
  end

  it "should add the taxon's wikipedia description as a GuideSection" do
    t = Taxon.make!(:wikipedia_summary => "foo bar")
    gt = GuideTaxon.make!(:taxon => t)
    gt.reload
    expect(gt.guide_sections).not_to be_blank
    expect(gt.guide_sections.first.description).to eq(t.wikipedia_summary)
  end

  it "should set the license for the default GuideSection to CC-BY-SA" do
    t = Taxon.make!(:wikipedia_summary => "foo bar")
    gt = GuideTaxon.make!(:taxon => t)
    gt.reload
    expect(gt.guide_sections.first.license).to eq(Observation::CC_BY_SA)
  end

  it "should update the guide's taxon id" do
    g = Guide.make!
    expect(g.taxon_id).to be_blank
    ancestor = Taxon.make!(rank: Taxon::GENUS)
    t1 = Taxon.make!(parent: ancestor, rank: Taxon::SPECIES)
    t2 = Taxon.make!(parent: ancestor, rank: Taxon::SPECIES)
    gt1 = without_delay { GuideTaxon.make!(:guide => g, :taxon => t1) }
    gt2 = without_delay { GuideTaxon.make!(:guide => g, :taxon => t2) }
    g.reload
    expect(g.taxon_id).to eq(ancestor.id)
  end

  it "should be impossible to create more than 500 guide taxa per guide" do
    g = Guide.make!
    500.times do
      GuideTaxon.make!(:guide => g)
    end
    gt = GuideTaxon.make(:guide => g)
    expect(gt).not_to be_valid
  end
end

describe GuideTaxon, "deletion" do
  it "should update the guide's taxon id" do
    without_delay do
      g = Guide.make!
      ancestor = Taxon.make!(rank: Taxon::GENUS)
      t1 = Taxon.make!(parent: ancestor, rank: Taxon::SPECIES)
      t2 = Taxon.make!
      gt1 = GuideTaxon.make!(:guide => g, :taxon => t1)
      gt2 = GuideTaxon.make!(:guide => g, :taxon => t2)
      g.reload
      expect(g.taxon_id).to be_blank
      gt2.destroy
      g.reload
      expect(g.taxon_id).to eq t1.parent_id
    end
  end
end

# Pretty sure none of EOL's collections remain, or the API is broken, or something, as of 2018-11-30
# describe GuideTaxon, "new_from_eol_collection_item" do
#   before do
#     eol = EolService.new( timeout: 30, debug: true )
#     @collection = eol.collections(6970, sort_by: "sort_field" )
#     @collection_item = @collection.search("item").detect{|item| item.at("name").inner_text =~ /Anniella/}
#     @guide = Guide.make!
#     @guide_taxon = GuideTaxon.new_from_eol_collection_item(@collection_item, :guide => @guide)
#   end

#   it "should set a source_identifier" do
#     expect(@guide_taxon.source_identifier).not_to be_blank
#     expect(@guide_taxon.source_identifier).to be =~ /eol.org\/pages\/\d+/
#   end
# end

describe GuideTaxon, "sync_site_content" do
  elastic_models( Observation )
  let(:t) {
    t = Taxon.make!(:wikipedia_summary => "Foo bar")
    6.times do
      p = Photo.make!(:license => Photo::CC_BY)
      TaxonPhoto.make!(:taxon => t, :photo => p)
    end
    TaxonName.make!(:taxon => t, :lexicon => "English")
    t.reload
    t
  }
  let(:gt) { GuideTaxon.make!(:taxon => t) }

  it "should set up to 5 photos" do
    expect(gt.taxon.photos.size).to be > 5
    gt.sync_site_content(:photos => true)
    expect(gt.guide_photos.size).to eq 5
  end

  it "should set a common name" do
    gt.update_attributes(:display_name => nil)
    expect(gt.display_name).to be_blank
    gt.sync_site_content(:names => true)
    expect(gt.display_name).to eq gt.taxon.common_name.name
  end

  it "should set a section" do
    gt.guide_sections.destroy_all
    expect(gt.guide_sections).to be_blank
    gt.sync_site_content(:summary => true)
    expect(gt.guide_sections.size).to eq 1
  end
end

describe GuideTaxon, "sync_eol" do
  let(:gt) { GuideTaxon.make! }
  elastic_models( Observation )
  before(:all) do
    Site.make!
    eol = EolService.new(:timeout => 30)
    @mflagellum_page ||= eol.page( 47046719,
      common_names: true,
      images_per_page: 5, 
      maps_per_page: 5, 
      texts_per_page: 5,
      details: true,
      cache_ttl: -1
    )
  end

  it "should update the display_name" do
    expect( gt.display_name.to_s.downcase ).not_to eq "coachwhip"
    gt.sync_eol(:page => @mflagellum_page, :replace => true)
    expect( gt.display_name.to_s.downcase ).to eq "coachwhip"
  end

  it "should allow replacement of existing content" do
    gp = GuidePhoto.make!(:guide_taxon => gt)
    gr = GuideRange.make!(:guide_taxon => gt)
    gs = GuideSection.make!(:guide_taxon => gt)
    gt.sync_eol(:page => @mflagellum_page, :replace => true, :photos => true, :ranges => true, :overview => true)
    expect(GuidePhoto.find_by_id(gp.id)).to be_blank
    expect(GuideRange.find_by_id(gr.id)).to be_blank
    expect(GuideSection.find_by_id(gs.id)).to be_blank
  end

  it "should not replace existing content if not requested" do
    original_name = "foo1"
    gt.update_attributes(:display_name => original_name)
    gp = GuidePhoto.make!(:guide_taxon => gt)
    gr = GuideRange.make!(:guide_taxon => gt)
    gs = GuideSection.make!(:guide_taxon => gt)
    gt.sync_eol(:page => @mflagellum_page, :photos => true, :ranges => true, :overview => true)
    gt.reload
    expect(gt.display_name).to eq original_name
    expect(GuidePhoto.find_by_id(gp.id)).not_to be_blank
    expect(GuideRange.find_by_id(gr.id)).not_to be_blank
    expect(GuideSection.find_by_id(gs.id)).not_to be_blank
  end

  it "should not add content for categories that weren't selected" do
    gt.guide_photos.destroy_all
    gt.guide_sections.destroy_all
    gt.guide_ranges.destroy_all
    expect(gt.guide_photos.count).to eq 0
    expect(gt.guide_sections.count).to eq 0
    expect(gt.guide_ranges.count).to eq 0
    gt.sync_eol(:page => @mflagellum_page, :photos => "0", :ranges => "0", :overview => "0")
    gt.reload
    expect(gt.guide_photos.count).to eq 0
    expect(gt.guide_sections.count).to eq 0
    expect(gt.guide_ranges.count).to eq 0
  end

  it "should add at least one secion if overview requested" do
    expect(gt.guide_sections).to be_blank
    gt.sync_eol(:page => @mflagellum_page, :overview => true)
    gt.reload
    expect(gt.guide_sections).not_to be_blank
  end

  # this doesn't pass b/c EOL's page api seems to return a GeneralDescription
  # when you request a Description. Could hack around it, of course, but would
  # rather the EOL API just behaved reasonably
  # it "should add a description section if requested" do
  #   expect(gt.guide_sections).to be_blank
  #   eol = EolService.new(:timeout => 30)
  #   page = eol.page(577775, :subjects => "Description")
  #   gt.sync_eol(:page => page, :subjects => %w(Description))
  #   gt.reload
  #   expect(gt.guide_sections).not_to be_blank
  # end
end

describe GuideTaxon, "sync_eol_photos" do
  let(:gt) { GuideTaxon.make! }
  elastic_models( Observation )
  before(:all) do
    eol = EolService.new(:timeout => 30)
    @mflagellum_page ||= eol.page( 47046719,
      common_names: true,
      images_per_page: 5, 
      maps_per_page: 5, 
      texts_per_page: 5,
      details: true,
      cache_ttl: -1
    )
  end

  it "should add new photos" do
    expect(gt.guide_photos).to be_blank
    gt.sync_eol_photos(:page => @mflagellum_page)
    gt.save!
    gt.reload
    expect(gt.guide_photos).not_to be_blank
  end

  it "should not add duplicate photos" do
    gt.sync_eol_photos(:page => @mflagellum_page)
    gt.save!
    s1 = gt.guide_photos.size
    gt.sync_eol_photos(:page => @mflagellum_page)
    gt.save!
    gt.reload
    s2 = gt.guide_photos.size
    expect(s2).to eq s1
  end

  it "should position new photos after existing ones" do
    gp = GuidePhoto.make!(:guide_taxon => gt)
    gt.sync_eol_photos(:page => @mflagellum_page)
    gt.save!
    gt.reload
    guide_photos = gt.guide_photos.sort_by(&:position)
    expect(guide_photos.first).to eq gp
    expect(guide_photos.last.position).to be > gp.position
  end

  # it "should not add maps" do
  #   page = EolService.page(791500, :common_names => true, :maps => 1, :details => true, :photos => 0)
  #   gt.sync_eol_photos(:page => page)
  #   if gp = gt.guide_photos.last
  #     puts "gp.attributes: #{gp.attributes.inspect}"
  #   end
  #   expect(gt.guide_photos).to be_blank
  # end
end

#
# I don't think EOL is returning range maps any more as of 2018-11-30
#
# describe GuideTaxon, "sync_eol_ranges" do
#   let(:gt) { GuideTaxon.make! }
#   before(:all) do
#     eol = EolService.new(:timeout => 30)
#     @mflagellum_page ||= eol.page( 47046719,
#       common_names: true,
#       images_per_page: 5, 
#       maps_per_page: 5, 
#       texts_per_page: 5,
#       details: true,
#       cache_ttl: -1
#     )
#   end
#   it "should add new ranges" do
#     expect(gt.guide_ranges).to be_blank
#     gt.sync_eol_ranges(:page => @mflagellum_page)
#     expect(gt.guide_ranges).not_to be_blank
#   end
#   it "should not add duplicate ranges" do
#     gt.sync_eol_ranges(:page => @mflagellum_page)
#     gt.save!
#     s1 = gt.guide_ranges.size
#     gt.sync_eol_ranges(:page => @mflagellum_page)
#     s2 = gt.guide_ranges.size
#     expect(s2).to eq s1
#   end
# end

#
# Basically all busted as of 2018-11-30 b/c the EOL page API doesn't seem to
# support subject or language filtering any more.
#
# describe GuideTaxon, "sync_eol_sections" do
#   let(:gt) { GuideTaxon.make! }
#   before(:all) do
#     eol = EolService.new(:timeout => 30)
#     @mflagellum_page ||= eol.page( 47046719,
#       common_names: true,
#       images_per_page: 10,
#       maps_per_page: 10,
#       texts_per_page: 10,
#       details: true
#     )
#   end
#   it "should add new sections" do
#     expect(gt.guide_sections).to be_blank
#     gt.sync_eol_sections(:page => @mflagellum_page)
#     expect(gt.guide_sections).not_to be_blank
#   end

#   it "should not add duplicate sections" do
#     gt.sync_eol_sections(:page => @mflagellum_page, :subjects => %w(TypeInformation))
#     gt.save
#     gt.reload
#     expect(gt.guide_sections.size).to eq 1
#     gt.sync_eol_sections(:page => @mflagellum_page, :subjects => %w(TypeInformation))
#     gt.save
#     gt.reload
#     expect(gt.guide_sections.size).to eq 1
#   end

#   it "should only add the requested subjects" do
#     gt.sync_eol_sections(:page => @mflagellum_page, :subjects => %w(TypeInformation))
#     gs = gt.guide_sections.last
#     expect(gs.description.to_s).to be =~ /Colorado Desert/
#   end

#   it "should not import multiple sections for the same subject" do
#     gt.sync_eol_sections(:page => @mflagellum_page, :subjects => %w(Distribution))
#     gt.save!
#     gt.reload
#     expect(gt.guide_sections.size).to eq 1
#   end

#   it "should position new photos after existing ones" do
#     gs = GuideSection.make!(:guide_taxon => gt)
#     gt.sync_eol_sections(:page => @mflagellum_page)
#     gt.save!
#     gt.reload
#     guide_sections = gt.guide_sections.sort_by(&:position)
#     expect(guide_sections.first).to eq gs
#     expect(guide_sections.last.position).to be > gs.position
#   end
# end

# 
# nothing wrong here, we just need to cache these responses so they don't fail when eol goes down (kueda 20160708)
#
# describe GuideTaxon, "get_eol_page" do
#   let(:gt) { GuideTaxon.make!(:name => "Masticophis flagellum") }
#   it "should retrieve photos if requested" do
#     page = gt.get_eol_page(:photos => 1)
#     img_data_object = page.search('dataObject').detect{|data_object| data_object.at('dataType').to_s =~ /StillImage/ }
#     expect(img_data_object).not_to be_blank
#     expect(img_data_object.at('mediaURL')).not_to be_blank
#   end
#   it "should retrieve ranges if requested" do
#     page = gt.get_eol_page(:ranges => 1)
#     expect(page.search('dataObject').detect{|data_object| data_object.at('dataSubtype').to_s =~ /Map/ }).not_to be_blank
#   end
#   it "should retrieve sections if requested" do
#     page = gt.get_eol_page(:sections => 1)
#     expect(page.search('dataObject').detect{|data_object| data_object.at('dataType').content == "http://purl.org/dc/dcmitype/Text" }).not_to be_blank
#   end
#   it "should retrieve sections of requested subjects" do
#     page = gt.get_eol_page(:sections => 1, :subjects => %w(TypeInformation))
#     expect(page.search('dataObject').detect{|data_object| 
#       data_object.at('dataType').content == "http://purl.org/dc/dcmitype/Text" &&
#         data_object.at('subject').try(:content) =~ /TypeInformation/ 
#     }).not_to be_blank
#   end
# end

describe GuideTaxon, "add_color_tags" do
  let(:yellow) { Color.make!(:value => "yellow") }
  let(:blue) { Color.make!(:value => "blue") }
  let(:taxon) { 
    t = Taxon.make!
    t.colors += [yellow, blue]
    t.save
    t
  }
  let(:gt) { GuideTaxon.make!(:taxon => taxon)}

  it "should add tags" do
    gt.add_color_tags
    expect(gt.tag_list).to include("color=yellow")
    expect(gt.tag_list).to include("color=blue")
  end
end

describe GuideTaxon, "add_rank_tag" do

  before do
    @genus = Taxon.make!(:rank => "genus")
    @tn = @genus.taxon_names.create(:lexicon => TaxonName::LEXICONS[:ENGLISH], :name => "Fulminator")
    @t = Taxon.make!(:rank => "species", :parent => @genus)
    @gt = GuideTaxon.make!(:taxon => @t)
  end

  it "should add tags" do
    expect(@genus.taxon_names.count).to eq 2
    @gt.add_rank_tag('genus', :lexicon => TaxonName::LEXICONS[:ENGLISH])
    expect(@gt.tag_list).to include("taxonomy:genus=#{@tn.name}")
  end

  it "should work for rank names that collide with keywords" do
    load_test_taxa
    gt = GuideTaxon.make!(:taxon => @Pseudacris_regilla)
    gt.add_rank_tag('order')
    expect(gt.tag_list).to include "taxonomy:order=Anura"
  end
end

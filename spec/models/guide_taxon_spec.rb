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
    gt.guide_sections.should_not be_blank
    gt.guide_sections.first.description.should eq(t.wikipedia_summary)
  end

  it "should set the license for the default GuideSection to CC-BY-SA" do
    t = Taxon.make!(:wikipedia_summary => "foo bar")
    gt = GuideTaxon.make!(:taxon => t)
    gt.reload
    gt.guide_sections.first.license.should eq(Observation::CC_BY_SA)
  end

  it "should update the guide's taxon id" do
    g = Guide.make!
    g.taxon_id.should be_blank
    ancestor = Taxon.make!
    t1 = Taxon.make!(:parent => ancestor)
    t2 = Taxon.make!(:parent => ancestor)
    gt1 = without_delay { GuideTaxon.make!(:guide => g, :taxon => t1) }
    gt2 = without_delay { GuideTaxon.make!(:guide => g, :taxon => t2) }
    g.reload
    g.taxon_id.should eq(ancestor.id)
  end
end

describe GuideTaxon, "deletion" do
  it "should update the guide's taxon id" do
    without_delay do
      g = Guide.make!
      ancestor = Taxon.make!
      t1 = Taxon.make!(:parent => ancestor)
      t2 = Taxon.make!
      gt1 = GuideTaxon.make!(:guide => g, :taxon => t1)
      gt2 = GuideTaxon.make!(:guide => g, :taxon => t2)
      g.reload
      g.taxon_id.should be_blank
      gt2.destroy
      g.reload
      g.taxon_id.should eq t1.parent_id
    end
  end
end

describe GuideTaxon, "new_from_eol_collection_item" do
  before do
    eol = EolService.new(:timeout => 30, :debug => true)
    @collection = eol.collections(6970, :sort_by => "sort_field")
    @collection_item = @collection.search("item").detect{|item| item.at("name").inner_text =~ /Anniella/}
    @guide = Guide.make!
    @guide_taxon = GuideTaxon.new_from_eol_collection_item(@collection_item, :guide => @guide)
  end

  it "should set a source_identifier" do
    @guide_taxon.source_identifier.should_not be_blank
    @guide_taxon.source_identifier.should =~ /eol.org\/pages\/\d+/
  end
end

describe GuideTaxon, "sync_site_content" do
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
    gt.taxon.photos.size.should > 5
    gt.sync_site_content(:photos => true)
    gt.guide_photos.size.should eq 5
  end

  it "should set a common name" do
    gt.update_attributes(:display_name => nil)
    gt.display_name.should be_blank
    gt.sync_site_content(:names => true)
    gt.display_name.should eq gt.taxon.common_name.name
  end

  it "should set a section" do
    gt.guide_sections.destroy_all
    gt.guide_sections.should be_blank
    gt.sync_site_content(:summary => true)
    gt.guide_sections.size.should eq 1
  end
end

describe GuideTaxon, "sync_eol" do
  let(:gt) { GuideTaxon.make! }
  before(:all) do
    eol = EolService.new(:timeout => 30)
    @mflagellum_page ||= eol.page(791500, :common_names => true, :images => 5, :details => true)
  end

  it "should update the display_name" do
    gt.display_name.should_not eq "coachwhip"
    gt.sync_eol(:page => @mflagellum_page)
    gt.display_name.should eq "coachwhip"
  end

  it "should allow replacement of existing content" do
    gp = GuidePhoto.make!(:guide_taxon => gt)
    gr = GuideRange.make!(:guide_taxon => gt)
    gs = GuideSection.make!(:guide_taxon => gt)
    gt.sync_eol(:page => @mflagellum_page, :replace => true, :photos => true, :ranges => true, :overview => true)
    GuidePhoto.find_by_id(gp.id).should be_blank
    GuideRange.find_by_id(gr.id).should be_blank
    GuideSection.find_by_id(gs.id).should be_blank
  end

  it "should not replace existing content if not requested" do
    gp = GuidePhoto.make!(:guide_taxon => gt)
    gr = GuideRange.make!(:guide_taxon => gt)
    gs = GuideSection.make!(:guide_taxon => gt)
    gt.sync_eol(:page => @mflagellum_page, :photos => true, :ranges => true, :overview => true)
    GuidePhoto.find_by_id(gp.id).should_not be_blank
    GuideRange.find_by_id(gr.id).should_not be_blank
    GuideSection.find_by_id(gs.id).should_not be_blank
  end

  it "should add at least one secion if overview requested" do
    gt.guide_sections.should be_blank
    gt.sync_eol(:page => @mflagellum_page, :overview => true)
    gt.reload
    gt.guide_sections.should_not be_blank
  end

  # this doesn't pass b/c EOL's page api seems to return a GeneralDescription
  # when you request a Description. Could hack around it, of course, but would
  # rather the EOL API just behaved reasonably
  # it "should add a description section if requested" do
  #   gt.guide_sections.should be_blank
  #   eol = EolService.new(:timeout => 30)
  #   page = eol.page(577775, :subjects => "Description")
  #   gt.sync_eol(:page => page, :subjects => %w(Description))
  #   gt.reload
  #   gt.guide_sections.should_not be_blank
  # end
end

describe GuideTaxon, "sync_eol_photos" do
  let(:gt) { GuideTaxon.make! }
  before(:all) do
    eol = EolService.new(:timeout => 30)
    @mflagellum_page ||= eol.page(791500, :common_names => true, :images => 5, :details => true)
  end

  it "should add new photos" do
    gt.guide_photos.should be_blank
    gt.sync_eol_photos(:page => @mflagellum_page)
    gt.save!
    gt.reload
    gt.guide_photos.should_not be_blank
  end

  it "should not add duplicate photos" do
    gt.sync_eol_photos(:page => @mflagellum_page)
    gt.save!
    s1 = gt.guide_photos.size
    gt.sync_eol_photos(:page => @mflagellum_page)
    gt.save!
    gt.reload
    s2 = gt.guide_photos.size
    s2.should eq s1
  end

  it "should position new photos after existing ones" do
    gp = GuidePhoto.make!(:guide_taxon => gt)
    gt.sync_eol_photos(:page => @mflagellum_page)
    gt.save!
    gt.reload
    guide_photos = gt.guide_photos.sort_by(&:position)
    guide_photos.first.should eq gp
    guide_photos.last.position.should > gp.position
  end

  # it "should not add maps" do
  #   page = EolService.page(791500, :common_names => true, :maps => 1, :details => true, :photos => 0)
  #   gt.sync_eol_photos(:page => page)
  #   if gp = gt.guide_photos.last
  #     puts "gp.attributes: #{gp.attributes.inspect}"
  #   end
  #   gt.guide_photos.should be_blank
  # end
end

describe GuideTaxon, "sync_eol_ranges" do
  let(:gt) { GuideTaxon.make! }
  before(:all) do
    eol = EolService.new(:timeout => 30)
    @mflagellum_page ||= eol.page(791500, :common_names => true, :images => 5, :details => true, :maps => 1)
  end
  it "should add new ranges" do
    gt.guide_ranges.should be_blank
    gt.sync_eol_ranges(:page => @mflagellum_page)
    gt.guide_ranges.should_not be_blank
  end
  it "should not add duplicate ranges" do
    gt.sync_eol_ranges(:page => @mflagellum_page)
    gt.save!
    s1 = gt.guide_ranges.size
    gt.sync_eol_ranges(:page => @mflagellum_page)
    s2 = gt.guide_ranges.size
    s2.should eq s1
  end
end

describe GuideTaxon, "sync_eol_sections" do
  let(:gt) { GuideTaxon.make! }
  before(:all) do
    eol = EolService.new(:timeout => 30)
    @mflagellum_page ||= eol.page(791500, :common_names => true, :images => 5, :details => true, :maps => 1, :text => 50)
  end
  it "should add new sections" do
    gt.guide_sections.should be_blank
    gt.sync_eol_sections(:page => @mflagellum_page)
    gt.guide_sections.should_not be_blank
  end

  it "should not add duplicate sections" do
    gt.sync_eol_sections(:page => @mflagellum_page, :subjects => %w(TypeInformation))
    gt.save
    gt.reload
    gt.guide_sections.size.should == 1
    gt.sync_eol_sections(:page => @mflagellum_page, :subjects => %w(TypeInformation))
    gt.save
    gt.reload
    gt.guide_sections.size.should == 1
  end

  it "should only add the requested subjects" do
    gt.sync_eol_sections(:page => @mflagellum_page, :subjects => %w(TypeInformation))
    gs = gt.guide_sections.last
    gs.description.to_s.should =~ /Colorado Desert/
  end

  it "should not import multiple sections for the same subject" do
    gt.sync_eol_sections(:page => @mflagellum_page, :subjects => %w(Distribution))
    gt.save!
    gt.reload
    gt.guide_sections.size.should eq 1
  end

  it "should position new photos after existing ones" do
    gs = GuideSection.make!(:guide_taxon => gt)
    gt.sync_eol_sections(:page => @mflagellum_page)
    gt.save!
    gt.reload
    guide_sections = gt.guide_sections.sort_by(&:position)
    guide_sections.first.should eq gs
    guide_sections.last.position.should > gs.position
  end
end

describe GuideTaxon, "get_eol_page" do
  let(:gt) { GuideTaxon.make!(:name => "Masticophis flagellum") }
  it "should retrieve photos if requested" do
    page = gt.get_eol_page(:photos => 1)
    img_data_object = page.search('dataObject').detect{|data_object| data_object.at('dataType').to_s =~ /StillImage/ }
    img_data_object.should_not be_blank
    img_data_object.at('mediaURL').should_not be_blank
  end

  it "should retrieve ranges if requested" do
    page = gt.get_eol_page(:ranges => 1)
    page.search('dataObject').detect{|data_object| data_object.at('dataSubtype').to_s =~ /Map/ }.should_not be_blank
  end

  it "should retrieve sections if requested" do
    page = gt.get_eol_page(:sections => 1)
    page.search('dataObject').detect{|data_object| data_object.at('dataType').content == "http://purl.org/dc/dcmitype/Text" }.should_not be_blank
  end

  it "should retrieve sections of requested subjects" do
    page = gt.get_eol_page(:sections => 1, :subjects => %w(TypeInformation))
    page.search('dataObject').detect{|data_object| 
      data_object.at('dataType').content == "http://purl.org/dc/dcmitype/Text" &&
        data_object.at('subject').try(:content) =~ /TypeInformation/ 
    }.should_not be_blank
  end
end

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
    gt.tag_list.should include("color=yellow")
    gt.tag_list.should include("color=blue")
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
    @genus.taxon_names.count.should eq 2
    @gt.add_rank_tag('genus', :lexicon => TaxonName::LEXICONS[:ENGLISH])
    @gt.tag_list.should include("taxonomy:genus=#{@tn.name}")
  end

  it "should work for rank names that collide with keywords" do
    load_test_taxa
    gt = GuideTaxon.make!(:taxon => @Pseudacris_regilla)
    gt.add_rank_tag('order')
    gt.tag_list.should include "taxonomy:order=Anura"
  end
end

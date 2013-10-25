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

# describe GuideTaxon, "new_from_eol_collection_item" do
#   before do
#     eol = EolService.new(:timeout => 30, :debug => true)
#     @collection = eol.collections(6970, :sort_by => "sort_field")
#     @collection_item = @collection.search("item").detect{|item| item.at("name").inner_text =~ /Anniella/}
#     @guide = Guide.make!
#     @guide_taxon = GuideTaxon.new_from_eol_collection_item(@collection_item, :guide => @guide)
#   end

#   it "should set a guide section from the annotation" do
#     @guide_taxon.guide_sections.first.description.should eq(@collection_item.at('annotation').inner_text)
#   end

#   it "should set a guide photo" do
#     @guide_taxon.guide_photos.should_not be_blank
#   end

#   it "should set the display_name to an appropriate common name" do
#     collection_item = @collection.search("item").detect{|item| item.at("name").inner_text =~ /Masticophis/}
#     gt = GuideTaxon.new_from_eol_collection_item(collection_item, :guide => @guide)
#     gt.display_name.downcase.should eq("coachwhip")
#   end
# end

describe GuideTaxon, "sync_eol" do
  let(:gt) { GuideTaxon.make! }
  before(:all) do
    @mflagellum_page ||= EolService.page(791500, :common_names => true, :images => 5, :details => true)
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
end

describe GuideTaxon, "sync_eol_photos" do
  let(:gt) { GuideTaxon.make! }
  before(:all) do
    @mflagellum_page ||= EolService.page(791500, :common_names => true, :images => 5, :details => true)
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
    @mflagellum_page ||= EolService.page(791500, :common_names => true, :images => 5, :details => true, :maps => 1)
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
    @mflagellum_page ||= EolService.page(791500, :common_names => true, :images => 5, :details => true, :maps => 1, :text => 50)
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
    # puts "img_data_object: #{img_data_object}"
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

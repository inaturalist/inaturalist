# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Guide, "reorder_by_taxon" do
  it "should work" do
    f1 = Taxon.make!(:rank => Taxon::FAMILY, :name => "family1")
    f2 = Taxon.make!(:rank => Taxon::FAMILY, :name => "family2")
    g1 = Taxon.make!(:rank => Taxon::GENUS, :parent => f1, :name => "genus1")
    g2 = Taxon.make!(:rank => Taxon::GENUS, :parent => f1, :name => "genus2")
    g3 = Taxon.make!(:rank => Taxon::GENUS, :parent => f2, :name => "genus3")
    s1 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g1, :name => "species1")
    s2 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g2, :name => "species2")
    s3 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g2, :name => "species3")
    s4 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g3, :name => "species4")
    g = Guide.make!
    gt4 = GuideTaxon.make!(:guide => g, :taxon => s4, :position => 1)
    gt3 = GuideTaxon.make!(:guide => g, :taxon => s3, :position => 2)
    gt2 = GuideTaxon.make!(:guide => g, :taxon => s2, :position => 3)
    gt1 = GuideTaxon.make!(:guide => g, :taxon => s1, :position => 4)
    g.guide_taxa.order(:position).first.should eq(gt4)
    g.reorder_by_taxonomy
    g.reload
    g.guide_taxa.order(:position).first.should eq(gt1)
  end
end

describe Guide, "set_defaults_from_eol_collection" do
  before do
    @guide = Guide.new
    @guide.set_defaults_from_eol_collection("http://eol.org/collections/6970")
  end

  it "should set a title" do
    @guide.title.should_not be_blank
  end

  it "should set a description" do
    @guide.description.should_not be_blank
  end
end

describe Guide, "add_taxa_from_eol_collection" do
  let(:eol_collection_url) { "http://eol.org/collections/6970" } 
  it "should add taxa" do
    # this is brittle, but these should be all the names on that list. If
    # they're not in the db, this will fail b/c the guide taxa will be invalid
    # without taxa to match.
    [
      'Hydromantes platycephalus',
      'Anniella pulchra',
      'Rhinocheilus lecontei',
      'Masticophis flagellum',
      'Bogertophis subocularis',
      'Aneides vagrans'
    ].each do |name|
      Taxon.make!(:name => name)
    end
    guide = Guide.make!
    guide.add_taxa_from_eol_collection(eol_collection_url)
    guide.guide_taxa.should_not be_blank
  end
end

describe Guide, "to_ngz" do
  before(:all) do
    ThinkingSphinx::Deltas.suspend!
    @guide = Guide.make!
    @guide_taxon = GuideTaxon.make!(:guide => @guide)
    @photo = FlickrPhoto.create!(
      "native_photo_id" => "6336919400",
      "square_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116_s.jpg",
      "thumb_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116_t.jpg",
      "small_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116_m.jpg",
      "medium_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116.jpg",
      "large_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116_b.jpg",
      "original_url" => "http://farm7.staticflickr.com/6220/6336919400_767093042c_o.jpg",
      "native_page_url" => "http://www.flickr.com/photos/ken-ichi/6336919400/",
      "native_username" => "Ken-ichi",
      "native_realname" => "Ken-ichi Ueda",
      "license" => 2
    )
    @guide_photo = GuidePhoto.make!(:guide_taxon => @guide_taxon, :photo => @photo)
    @guide_range = GuideRange.make!(
      :guide_taxon => @guide_taxon,
      "medium_url" => "http://www.natureserve.org/imagerepository/GetImage?SRC=6&BATCH=50&FMT=gif&RES=600X615&NAME=rhinocheilus_lecontei",
      "thumb_url" => "http://media.eol.org/content/2011/12/03/16/44985_98_68.jpg",
      "original_url" => "http://www.natureserve.org/imagerepository/GetImage?SRC=6&BATCH=50&FMT=gif&RES=600X615&NAME=rhinocheilus_lecontei",
      "license" => "CC-BY-NC",
      "source_url" => "http://eol.org/data_objects/14528560",
      "rights_holder" => "NatureServe"
    )
    @guide_section = GuideSection.make!(:guide_taxon => @guide_taxon)
    @zip_path = @guide.to_ngz
    @unzipped_path = File.join File.dirname(@zip_path), @guide.to_param
    system "unzip -qd #{@unzipped_path} #{@zip_path}"
  end

  after(:all) do
    ThinkingSphinx::Deltas.resume!
  end

  it "should contain an xml file" do
    Dir.glob(File.join(@unzipped_path, "*.xml")).should_not be_blank
  end

  it "should have guide photo image files" do
    File.exist?(File.join(@unzipped_path, "files", FakeView.guide_asset_filename(@guide_photo, :size => "medium"))).should be true
  end

  it "should have guide range image files" do
    File.exist?(File.join(@unzipped_path, "files", FakeView.guide_asset_filename(@guide_range, :size => "medium"))).should be true
  end
end

describe Guide, "ngz" do
  let(:g) { Guide.make! }

  it "should generate when downloadable changed to true" do
    g.ngz.url.should be_blank
    g.update_attributes(:downloadable => true)
    Delayed::Worker.new(:quiet => true).work_off
    g.reload
    g.ngz.url.should_not be_blank
  end

  it "job should not trigger if no relevant attributes changed" do
    g
    Delayed::Job.delete_all
    g.update_attributes :zoom_level => 5
    Delayed::Job.all.each {|j| puts j.handler} if Delayed::Job.count > 0
    Delayed::Job.count.should eq 0
  end

  it "should be removed when downloadable changed to false" do
    g.ngz.url.should be_blank
    g.update_attributes(:downloadable => true)
    Delayed::Worker.new(:quiet => true).work_off
    g.reload
    g.ngz.url.should_not be_blank
    g.update_attributes(:downloadable => false)
    g.ngz.url.should be_blank
  end

  it "job should only queue once" do
    g
    Delayed::Job.delete_all
    g.update_attributes(:downloadable => true)
    g.update_attributes(:downloadable => false)
    g.update_attributes(:downloadable => true)
    Delayed::Job.all.each {|j| puts j.handler} if Delayed::Job.count > 1
    Delayed::Job.count.should eq 1
  end
end

describe Guide, "publication" do
  it "should not be allowed for guides with less than 3 taxa" do
    g = Guide.make!
    g.update_attributes(:published_at => Time.now)
    g.errors[:published_at].should_not be_blank
    
    2.times do
      GuideTaxon.make!(:guide => g)
    end
    g.reload
    g.update_attributes(:published_at => Time.now)
    g.errors[:published_at].should_not be_blank

    GuideTaxon.make!(:guide => g)
    g.reload
    g.update_attributes(:published_at => Time.now)
    g.errors[:published_at].should be_blank
    g.should be_valid
  end
end

describe Guide, "creation" do
  it "should create a guide user" do
    g = Guide.make!
    g.guide_users.where(:user_id => g.user_id).should_not be_blank
  end
end

describe Guide, "deletion" do
  let(:g) { Guide.make! }
  it "should remove guide users" do
    g.destroy
    GuideUser.where(:guide_id => g.id).should be_blank
  end
end


# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Guide do
  it { is_expected.to belong_to(:user).inverse_of :guides }
  it { is_expected.to belong_to(:place).inverse_of :guides }
  it { is_expected.to belong_to(:taxon).inverse_of :guides }
  it { is_expected.to have_many(:guide_taxa).inverse_of(:guide).dependent :destroy }
  it { is_expected.to have_many(:guide_users).inverse_of(:guide).dependent :delete_all }

  it { is_expected.to validate_length_of(:title).is_at_least(3).is_at_most 255 }

  describe "reorder_by_taxon" do
    before do
      Taxon.destroy_all
    end
    it "should work" do
      f1 = Taxon.make!(:rank => Taxon::FAMILY, :name => "Familyone")
      f2 = Taxon.make!(:rank => Taxon::FAMILY, :name => "Familytwo")
      g1 = Taxon.make!(:rank => Taxon::GENUS, :parent => f1, :name => "Genusone")
      g2 = Taxon.make!(:rank => Taxon::GENUS, :parent => f1, :name => "Genustwo")
      g3 = Taxon.make!(:rank => Taxon::GENUS, :parent => f2, :name => "Genusthree")
      s1 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g1, :name => "Species one")
      s2 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g2, :name => "Species two")
      s3 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g2, :name => "Species three")
      s4 = Taxon.make!(:rank => Taxon::SPECIES, :parent => g3, :name => "Species four")
      g = Guide.make!
      gt4 = GuideTaxon.make!(:guide => g, :taxon => s4, :position => 1)
      gt3 = GuideTaxon.make!(:guide => g, :taxon => s3, :position => 2)
      gt2 = GuideTaxon.make!(:guide => g, :taxon => s2, :position => 3)
      gt1 = GuideTaxon.make!(:guide => g, :taxon => s1, :position => 4)
      expect(g.guide_taxa.order(:position).first).to eq(gt4)
      g.reorder_by_taxonomy
      g.reload
      expect(g.guide_taxa.order(:position).first).to eq(gt1)
    end
  end

  describe "to_ngz" do
    elastic_models( Observation )
    before(:all) do
      @guide = Guide.make!
      @guide_taxon = GuideTaxon.make!(:guide => @guide)
      @photo = FlickrPhoto.create!(
          "native_photo_id" => "6336919400",
          "remote_square_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116_s.jpg",
          "remote_thumb_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116_t.jpg",
          "remote_small_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116_m.jpg",
          "remote_medium_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116.jpg",
          "remote_large_url" => "http://farm7.staticflickr.com/6220/6336919400_64fb863116_b.jpg",
          "remote_original_url" => "http://farm7.staticflickr.com/6220/6336919400_767093042c_o.jpg",
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
      FileUtils.rm_rf("#{@unzipped_path}/") if Dir.exists?(@unzipped_path)
      system "unzip -qd #{@unzipped_path} #{@zip_path}"
    end

    after(:all) do
      FileUtils.rm_rf("#{@unzipped_path}/") if Dir.exists?(@unzipped_path)
    end

    it "should generate a .ngz file in the tmp directory" do
      expect(File.exists?("#{@guide.ngz_work_path}.ngz")).to be true
    end

    it "should clean up its working directory" do
      expect(Dir.exists?(@guide.ngz_work_path)).to be false
    end

    it "should contain an xml file" do
      expect(Dir.glob(File.join(@unzipped_path, "*.xml"))).not_to be_blank
    end

    it "should have guide photo image files" do
      expect(File.exist?(File.join(@unzipped_path, "files", FakeView.guide_asset_filename(@guide_photo, :size => "medium")))).to be true
    end

    it "should have guide range image files" do
      expect(File.exist?(File.join(@unzipped_path, "files", FakeView.guide_asset_filename(@guide_range, :size => "medium")))).to be true
    end
  end

  describe "generate_ngz" do
    before(:all) do
      @guide = Guide.make!
      GuideTaxon.make!(guide: @guide)
    end

    it "should delete the temp file after saving the record" do
      # create a temp file so we can confirm it exists
      temp_ngz_path = @guide.to_ngz
      expect(File.exists?(temp_ngz_path)).to be true
      expect(@guide.ngz.path).to be_nil
      # now generate_ngz, which will create the temp file again
      # but then delete it after saving the record
      @guide.generate_ngz
      expect(File.exists?(temp_ngz_path)).to be false
      expect(@guide.ngz.path).to_not be_nil
    end
  end

  describe "ngz" do
    let(:g) { Guide.make! }

    it "should generate when downloadable changed to true" do
      expect(g.ngz.url).to be_blank
      g.update(:downloadable => true)
      Delayed::Worker.new(:quiet => true).work_off
      g.reload
      expect(g.ngz.url).not_to be_blank
    end

    it "job should not trigger if no relevant attributes changed" do
      g
      Delayed::Job.delete_all
      g.update :zoom_level => 5
      Delayed::Job.all.each {|j| puts j.handler} if Delayed::Job.count > 0
      expect(
        Delayed::Job.where( "handler NOT LIKE '%invalidate_cloudfront_cache_for%'").count
      ).to eq 0
    end

    it "should be removed when downloadable changed to false" do
      expect(g.ngz.url).to be_blank
      g.update(:downloadable => true)
      Delayed::Worker.new(:quiet => true).work_off
      g.reload
      expect(g.ngz.url).not_to be_blank
      g.update(:downloadable => false)
      expect(g.ngz.url).to be_blank
    end

    it "job should only queue once" do
      g
      Delayed::Job.delete_all
      g.update(:downloadable => true)
      g.update(:downloadable => false)
      g.update(:downloadable => true)
      expect(
        Delayed::Job.where( "handler NOT LIKE '%invalidate_cloudfront_cache_for%'").count
      ).to eq 1
    end
  end

  describe "publication" do
    it "should not be allowed for guides with less than 3 taxa" do
      g = Guide.make!
      g.update(:published_at => Time.now)
      expect(g.errors[:published_at]).not_to be_blank

      2.times do
        GuideTaxon.make!(:guide => g)
      end
      g.reload
      g.update(:published_at => Time.now)
      expect(g.errors[:published_at]).not_to be_blank

      GuideTaxon.make!(:guide => g)
      g.reload
      g.update(:published_at => Time.now)
      expect(g.errors[:published_at]).to be_blank
      expect(g).to be_valid
    end
  end

  describe "creation" do
    it "should create a guide user" do
      g = Guide.make!
      expect(g.guide_users.where(:user_id => g.user_id)).not_to be_blank
    end
  end

  describe "deletion" do
    let(:g) { Guide.make! }
    it "should remove guide users" do
      g.destroy
      expect(GuideUser.where(:guide_id => g.id)).to be_blank
    end
  end
end

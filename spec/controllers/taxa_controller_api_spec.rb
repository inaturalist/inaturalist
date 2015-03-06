require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a TaxaController" do
  describe "index" do
    it "should filter by place_id" do
      t = Taxon.make!
      p = Place.make!
      p.check_list.add_taxon(t)
      get :index, :format => :json, :place_id => p.id
      expect(response.headers['X-Total-Entries'].to_i).to eq(1)
    end

    it "should show iconic taxa if no search params" do
      t = Taxon.make!(:is_iconic => true)
      d = Taxon.make!
      get :index, :format => :json
      json = JSON.parse(response.body)
      json.each do |json_taxon|
        expect(json_taxon['is_iconic']).to be true
      end
    end

    it "should filter by names" do
      t1 = Taxon.make!
      t2 = Taxon.make!
      t3 = Taxon.make!
      taxa = [t1,t2,t3]
      get :index, :format => :json, :names => taxa.map(&:name).join(',')
      json = JSON.parse(response.body)
      expect(json.size).to eq 3
      taxa.each do |t|
        expect(json.detect{|jt| jt["id"] == t.id}).not_to be_blank
      end
    end
  end

  describe "show" do
    it "should include range kml url" do
      tr = TaxonRange.make!(:url => "http://foo.bar/range.kml")
      get :show, :format => :json, :id => tr.taxon_id
      response_taxon = JSON.parse(response.body)
      expect(response_taxon['taxon_range_kml_url']).to eq tr.kml_url
    end

    describe "with default photo" do
      let(:photo) { 
        Photo.make!(
          "id" => 1576,
          "large_url" => "http://staticdev.inaturalist.org/photos/1576/large.jpg?1369951594",
          "license" => 4,
          "medium_url" => "http://staticdev.inaturalist.org/photos/1576/medium.jpg?1369951594",
          "native_page_url" => "http://localhost:3000/photos/1576",
          "native_photo_id" => "1576",
          "native_username" => "kueda",
          "original_url" => "http://staticdev.inaturalist.org/photos/1576/original.jpg?1369951594",
          "small_url" => "http://staticdev.inaturalist.org/photos/1576/small.jpg?1369951594",
          "square_url" => "http://staticdev.inaturalist.org/photos/1576/square.jpg?1369951594",
          "thumb_url" => "http://staticdev.inaturalist.org/photos/1576/thumb.jpg?1369951594"
        ) 
      }
      let(:taxon_photo) { TaxonPhoto.make!(:photo => photo) }
      let(:taxon) { taxon_photo.taxon }

      it "should include all image url sizes" do
        get :show, :format => :json, :id => taxon.id
        response_taxon = JSON.parse(response.body)
        %w(thumb small medium large).each do |size|
          expect(response_taxon['default_photo']["#{size}_url"]).to eq photo.send("#{size}_url")
        end
      end

      it "should include license url" do
        get :show, :format => :json, :id => taxon.id
        response_taxon = JSON.parse(response.body)
        expect(response_taxon['default_photo']['license_url']).to eq photo.license_url
      end
    end
  end

  describe "children" do
    it "should only show active taxa by default" do
      p = Taxon.make!
      active = Taxon.make!(:parent => p)
      inactive = Taxon.make!(:parent => p, :is_active => false)
      get :children, :id => p.id, :format => :json
      taxa = JSON.parse(response.body)
      expect(taxa.detect{|t| t['id'] == active.id}).not_to be_blank
      expect(taxa.detect{|t| t['id'] == inactive.id}).to be_blank
    end
    it "should show all taxa if requested" do
      p = Taxon.make!
      active = Taxon.make!(:parent => p)
      inactive = Taxon.make!(:parent => p, :is_active => false)
      get :children, :id => p.id, :format => :json, :is_active => "any"
      taxa = JSON.parse(response.body)
      expect(taxa.detect{|t| t['id'] == active.id}).not_to be_blank
      expect(taxa.detect{|t| t['id'] == inactive.id}).not_to be_blank
    end
  end
end

describe TaxaController, "oauth authentication" do
  let(:user) { User.make! }
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a TaxaController"
end

describe TaxaController, "devise authentication" do
  let(:user) { User.make! }
  before do
    http_login(user)
  end
  it_behaves_like "a TaxaController"
end

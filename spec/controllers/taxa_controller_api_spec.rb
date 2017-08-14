require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a TaxaController" do
  describe "index" do
    before(:each) { enable_elastic_indexing( Observation ) }
    after(:each) { disable_elastic_indexing( Observation ) }
    it "should filter by place_id" do
      t = Taxon.make!
      p = Place.make!
      without_delay do
        p.check_list.add_taxon(t)
      end
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

  describe "search" do
    before(:each) { enable_elastic_indexing( Observation, Taxon, Place ) }
    after(:each) { disable_elastic_indexing( Observation, Taxon, Place ) }

    it "should filter by place_id" do
      taxon_not_in_place = Taxon.make!
      taxon_in_place = Taxon.make!
      p = Place.make!
      without_delay do
        p.check_list.add_taxon(taxon_in_place)
      end
      get :search, format: :json, places: p.id.to_s
      json = JSON.parse(response.body)
      expect(json.detect{|t| t['id'] == taxon_not_in_place.id}).to be_blank
      expect(json.detect{|t| t['id'] == taxon_in_place.id}).not_to be_blank
    end

    it "returns results in the configured place" do
      taxon_not_in_place = Taxon.make!(name: "Disco stu")
      taxon_in_place = Taxon.make!(name: "Disco stu")
      p = Place.make!
      without_delay do
        p.check_list.add_taxon(taxon_in_place)
      end
      Site.default.update_attributes(place_id: p.id)
      get :search, format: :json, q: "disco"
      json = JSON.parse(response.body)
      expect(json.detect{|t| t['id'] == taxon_not_in_place.id}).to be_blank
      expect(json.detect{|t| t['id'] == taxon_in_place.id}).not_to be_blank
    end

    it "returns all results when there are none in the configured place" do
      taxon_not_in_place = Taxon.make!(name: "nonsense")
      taxon2_not_in_place = Taxon.make!(name: "nonsense")
      p = Place.make!
      Site.default.update_attributes(place_id: p.id)
      get :search, format: :json, q: "nonsense"
      json = JSON.parse(response.body)
      expect(json.detect{|t| t['id'] == taxon_not_in_place.id}).not_to be_blank
      expect(json.detect{|t| t['id'] == taxon2_not_in_place.id}).not_to be_blank
    end

    it "filters by is_active=true" do
      active = Taxon.make!(is_active: true)
      inactive = Taxon.make!(is_active: false)
      get :search, format: :json, is_active: "true"
      json = JSON.parse(response.body)
      expect(json.length).to eq 1
      expect(json.first["id"]).to eq active.id
    end

    it "filters by is_active=false" do
      active = Taxon.make!(is_active: true)
      inactive = Taxon.make!(is_active: false)
      get :search, format: :json, is_active: "false"
      json = JSON.parse(response.body)
      expect(json.length).to eq 1
      expect(json.first["id"]).to eq inactive.id
    end

    it "returns all taxa when is_active=any" do
      active = Taxon.make!(is_active: true)
      inactive = Taxon.make!(is_active: false)
      get :search, format: :json, is_active: "any"
      json = JSON.parse(response.body)
      expect(json.length).to eq 2
    end

    it "should place an exact match first" do
      [
        ["Octopus rubescens", "Eastern Pacific Red Octopus octopus octopus octopus"],
        ["Octopus bimaculatus", "Two-spot Octopus"],
        ["Octopus cyanea", "Day Octopus"],
        ["Schefflera actinophylla", "octopus there"],
        ["Octopus vulgaris", "Day Octopus"],
        ["Enteroctopus dofleini", "Giant Pacific Octopus"]
      ].each do |sciname, comname|
        t = Taxon.make!(name: sciname, rank: 'species')
        TaxonName.make!(taxon: t, name: comname)
      end
      t = Taxon.make!(name: "Octopus", rank: "genus")
      get :search, format: :json, q: 'octopus'
      names = JSON.parse(response.body).map{|jt| jt['name']}
      expect( names.first ).to eq t.name
    end

    it "should not return exact results of inactive taxa" do
      t = Taxon.make!(name: "Octopus", rank: "genus", is_active: true)
      get :search, format: :json, q: "octopus"
      expect( JSON.parse(response.body).first["name"] ).to eq t.name
      t.update_attribute(:is_active, false)
      get :search, format: :json, q: "octopus"
      expect( JSON.parse(response.body) ).to be_empty
    end

    # unfortunately i don't really know how to test this b/c it's not clear
    # how elasticsearch sorts its results
    it "should place an exact match first even if it's not on the first page of results"
  end

  describe "autocomplete" do
    before(:each) { enable_elastic_indexing([ Observation, Taxon, Place ]) }
    after(:each) { disable_elastic_indexing([ Observation, Taxon, Place ]) }

    it "filters by is_active=true" do
      active = Taxon.make!(name: "test", is_active: true)
      inactive = Taxon.make!(name: "test", is_active: false)
      get :autocomplete, format: :json, q: "test", is_active: "true"
      json = JSON.parse(response.body)
      expect(json.length).to eq 1
      expect(json.first["id"]).to eq active.id
    end

    it "filters by is_active=false" do
      active = Taxon.make!(name: "test", is_active: true)
      inactive = Taxon.make!(name: "test", is_active: false)
      get :autocomplete, format: :json, q: "test", is_active: "false"
      json = JSON.parse(response.body)
      expect(json.length).to eq 1
      expect(json.first["id"]).to eq inactive.id
    end

    it "returns all taxa when is_active=any" do
      active = Taxon.make!(name: "test", is_active: true)
      inactive = Taxon.make!(name: "test", is_active: false)
      get :autocomplete, format: :json, q: "test", is_active: "any"
      json = JSON.parse(response.body)
      expect(json.length).to eq 2
    end
  end

  describe "show" do
    before(:each) { enable_elastic_indexing( Observation ) }
    after(:each) { disable_elastic_indexing( Observation ) }
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

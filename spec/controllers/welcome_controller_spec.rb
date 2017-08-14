require 'spec_helper'

describe WelcomeController do

  describe "set_homepage_wiki" do
    before(:each) { enable_elastic_indexing(Observation) }
    after(:each) { disable_elastic_indexing(Observation) }
    let( :site ) { Site.default }
    before(:all) do
      @home = WikiPage.make!(path: "home")
      @homeES = WikiPage.make!(path: "eshome")
      @homeFR = WikiPage.make!(path: "frhome")
    end

    it "doesn't set @page if there is no home_page_wiki_path" do
      site.preferred_home_page_wiki_path = nil
      site.save!
      get :index
      expect( assigns[:page] ).to be nil
    end

    it "sets @page based on home_page_wiki_path" do
      site.preferred_home_page_wiki_path = @home.path
      site.save!
      get :index
      expect( assigns[:page] ).to eq @home
    end

    it "doesn't set @page if the path is wrong" do
      site.preferred_home_page_wiki_path = "nonsense"
      site.save!
      get :index
      expect( assigns[:page] ).to be nil
    end

    it "sets @page based on home_page_wiki_path_by_locale" do
      site.preferred_home_page_wiki_path = @home.path
      site.preferred_home_page_wiki_path_by_locale = { es: @homeES.path, fr: @homeFR.path }.to_json
      site.save!
      get :index
      expect( assigns[:page] ).to eq @home
      get :index, locale: "es"
      expect( assigns[:page] ).to eq @homeES
      get :index, locale: "fr"
      expect( assigns[:page] ).to eq @homeFR
    end

  end

end

# frozen_string_literal: true

require "spec_helper"

describe WelcomeController do
  describe "set_homepage_wiki" do
    elastic_models( Observation )
    let( :site ) { Site.default }
    before( :all ) do
      @home = WikiPage.make!( path: "home" )
      @home_es = WikiPage.make!( path: "eshome" )
      @home_fr = WikiPage.make!( path: "frhome" )
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
      site.preferred_home_page_wiki_path_by_locale = { es: @home_es.path, fr: @home_fr.path }.to_json
      site.save!
      get :index
      expect( assigns[:page] ).to eq @home
      get :index, params: { locale: "es" }
      expect( assigns[:page] ).to eq @home_es
      get :index, params: { locale: "fr" }
      expect( assigns[:page] ).to eq @home_fr
    end
  end
end

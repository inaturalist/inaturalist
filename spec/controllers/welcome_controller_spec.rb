require 'spec_helper'

describe WelcomeController do

  describe "set_homepage_wiki" do
    before(:each) { enable_elastic_indexing(Observation) }
    after(:each) { disable_elastic_indexing(Observation) }
    before(:all) do
      @home = WikiPage.make!(path: "home")
      @homeES = WikiPage.make!(path: "eshome")
      @homeFR = WikiPage.make!(path: "frhome")
    end

    it "doesn't set @page if there is no home_page_wiki_path" do
      expect( CONFIG ).to receive( :home_page_wiki_path ).at_least(:once).
        and_return( nil )
      get :index
      expect( assigns[:page] ).to be nil
    end

    it "sets @page based on home_page_wiki_path" do
      expect( CONFIG ).to receive( :home_page_wiki_path ).at_least(:once).
        and_return( "home" )
      get :index
      expect( assigns[:page] ).to eq @home
    end

    it "doesn't set @page if the path is wrong" do
      expect( CONFIG ).to receive( :home_page_wiki_path ).at_least(:once).
        and_return( "nonsense" )
      get :index
      expect( assigns[:page] ).to be nil
    end

    it "sets @page based on home_page_wiki_path_by_locale" do
      expect( CONFIG ).to receive( :home_page_wiki_path ).at_least(:once).
        and_return( "home" )
      expect( CONFIG ).to receive( :home_page_wiki_path_by_locale ).at_least(:once).
        and_return( OpenStruct.new(es: "eshome", fr: "frhome") )
      get :index
      expect( assigns[:page] ).to eq @home
      get :index, locale: "es"
      expect( assigns[:page] ).to eq @homeES
      get :index, locale: "fr"
      expect( assigns[:page] ).to eq @homeFR
    end

  end

end

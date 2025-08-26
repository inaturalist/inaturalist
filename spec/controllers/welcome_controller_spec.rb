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

  describe "announcements" do
    it "should target a site" do
      site = create :site
      annc = create :announcement, placement: Announcement::WELCOME_INDEX
      annc.sites << site
      get :index, params: { inat_site_id: site.id }
      expect( assigns( :announcements ) ).to include annc
    end

    it "should include an anouncement without a site if one with a site exists" do
      annc = create :announcement, placement: Announcement::WELCOME_INDEX
      site = create :site
      site_annc = create :announcement, placement: Announcement::WELCOME_INDEX
      site_annc.sites << site
      get :index, params: { inat_site_id: site.id }
      expect( assigns( :announcements ) ).to include site_annc
      expect( assigns( :announcements ) ).to include annc
    end

    # The intent is to allow the creation of a siteless announcement that can
    # be *overridden* for a site, e.g. an announcement to all iNat users that
    # iNatMX chooses to translate into Spanish
    it "should not include an anouncement without a site if one with a site that excludes non-site ones exists" do
      annc = create :announcement, placement: Announcement::WELCOME_INDEX
      site = create :site
      site_annc = create :announcement, placement: Announcement::WELCOME_INDEX, excludes_non_site: true
      site_annc.sites << site
      get :index, params: { inat_site_id: site.id }
      expect( assigns( :announcements ) ).to include site_annc
      expect( assigns( :announcements ) ).not_to include annc
    end

    it "should target locales" do
      a = create :announcement, placement: Announcement::WELCOME_INDEX
      locale_a = create :announcement, placement: Announcement::WELCOME_INDEX, locales: ["es"]
      u = User.make!( locale: "es" )
      sign_in u
      get :index, params: { locale: "es" }
      expect( assigns( :announcements ) ).to include locale_a
      expect( assigns( :announcements ) ).not_to include a
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

describe WikiPagesHelper do
  describe "wiki_nav" do
    let( :page ) { WikiPage.make!( title: "About", path: "about" ) }

    before { @page = page }

    it "renders links for each page title" do
      WikiPage.make!( title: "Team", path: "team" )
      result = wiki_nav( "{{nav About, Team}}" )
      expect( result ).to include( "about" )
      expect( result ).to include( "team" )
    end

    it "falls back to path lookup when title does not match exactly" do
      WikiPage.make!( title: "Resources for sharing about iNaturalist", path: "resources" )
      result = wiki_nav( "{{nav resources}}" )
      expect( result ).to include( "/pages/resources" )
    end

    it "uses page title as link text by default" do
      resources_page = WikiPage.make!( title: "Resources for sharing about iNaturalist", path: "resources" )
      result = wiki_nav( "{{nav resources}}" )
      expect( result ).to include( resources_page.title )
    end

    it "supports a custom label with pipe syntax" do
      WikiPage.make!( title: "Resources for sharing about iNaturalist", path: "resources" )
      result = wiki_nav( "{{nav resources|Resources}}" )
      expect( result ).to include( ">Resources<" )
      expect( result ).to include( "/pages/resources" )
    end

    it "custom label does not show the full page title when a label is given" do
      WikiPage.make!( title: "Resources for sharing about iNaturalist", path: "resources" )
      result = wiki_nav( "{{nav resources|Resources}}" )
      expect( result ).not_to include( "Resources for sharing about iNaturalist" )
    end

    it "marks the current page link as active" do
      result = wiki_nav( "{{nav About}}" )
      expect( result ).to include( "active" )
    end

    it "does not mark other pages as active" do
      WikiPage.make!( title: "Team", path: "team" )
      result = wiki_nav( "{{nav Team}}" )
      expect( result ).not_to include( "active" )
    end
  end
end

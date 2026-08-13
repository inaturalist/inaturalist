# frozen_string_literal: true

require "spec_helper"

describe "layouts/bootstrap" do
  describe "fathom analytics" do
    it "does not include tracker JS if site does not have a tracker ID" do
      @site = Site.make!
      render
      expect( rendered ).to_not have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js"
      } )
    end

    it "does not include tracker JS if the tracker ID is an empty string" do
      @site = Site.make!( preferred_fathom_analytics_tracker_id: "" )
      render
      expect( rendered ).to_not have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js"
      } )
    end

    it "includes tracker JS if site has a tracker ID" do
      @site = Site.make!( preferred_fathom_analytics_tracker_id: "test_fathom_tracker_id" )
      render
      expect( rendered ).to have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js",
        "data-site": "test_fathom_tracker_id",
        "data-canonical": "false"
      } )
    end

    it "includes tracker JS if site has a tracker ID and user is logged in" do
      @site = Site.make!( preferred_fathom_analytics_tracker_id: "test_fathom_tracker_id" )
      render template: "layouts/bootstrap", locals: { current_user: User.make! }
      expect( rendered ).to have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js",
        "data-site": "test_fathom_tracker_id",
        "data-canonical": "false"
      } )
    end

    it "does not include tracker JS if site has a tracker ID, but current user opts out" do
      @site = Site.make!( preferred_fathom_analytics_tracker_id: "test_fathom_tracker_id" )
      render template: "layouts/bootstrap", locals: { current_user: User.make!( prefers_no_tracking: true ) }
      expect( rendered ).to_not have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js"
      } )
    end
  end

  describe "test group toggle" do
    before { @site = Site.make! }

    it "renders the banner of an opted-in page at the top of the wrapper" do
      allow( view ).to receive( :current_user ).and_return( User.make! )
      allow( view ).to receive( :logged_in? ).and_return( true )
      @test_group_toggle = "responsive-global"
      render
      wrapper = Nokogiri::HTML( rendered ).at_css( "#wrapper" )
      expect( wrapper.element_children.first.to_html ).to include( "TestGroupBanner" )
    end

    it "renders no banner for a page that has not opted in" do
      allow( view ).to receive( :current_user ).and_return( User.make! )
      allow( view ).to receive( :logged_in? ).and_return( true )
      render
      expect( rendered ).not_to have_tag( "div.TestGroupBanner" )
    end

    it "renders a dismiss button for a user who has not joined the group" do
      allow( view ).to receive( :current_user ).and_return( User.make! )
      allow( view ).to receive( :logged_in? ).and_return( true )
      @test_group_toggle = "responsive-global"
      render
      expect( rendered ).to have_tag( "button.TestGroupBanner-dismiss" )
    end

    it "renders no dismiss button for a user who has joined the group" do
      allow( view ).to receive( :current_user ).and_return( User.make!( test_groups: "responsive-global" ) )
      allow( view ).to receive( :logged_in? ).and_return( true )
      @test_group_toggle = "responsive-global"
      render
      expect( rendered ).not_to have_tag( "button.TestGroupBanner-dismiss" )
    end
  end

  describe "flash" do
    before { @site = Site.make! }
    it "shows flash content for supported types" do
      %w(success alert notice error).each do | flash_type |
        flash[flash_type] = "congratulations on your #{flash_type}"
        render
        expect( rendered ).to have_tag( :div, with: { class: "alert" } ) do
          have_tag :p, with: { text: flash[flash_type] }
        end
      end
    end
    it "does not show flash content for unsupported types" do
      flash[:nope] = "what ho there"
      render
      expect( rendered ).not_to have_tag( :div, with: { class: "alert", text: flash[:nope] } )
    end
  end
end

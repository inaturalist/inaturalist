require "spec_helper"

describe "layouts/bootstrap" do
  describe "fathom analytics" do
    it "does not include tracker JS if site does not have a tracker ID" do
      @site = Site.make!
      render
      expect(rendered).to_not have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js"
      } )
    end

    it "includes tracker JS if site has a tracker ID" do
      @site = Site.make!( preferred_fathom_analytics_tracker_id: "test_fathom_tracker_id" )
      render
      expect(rendered).to have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js",
        "data-site": "test_fathom_tracker_id",
        "data-canonical": "false"
      } )
    end

    it "includes tracker JS if site has a tracker ID and user is logged in" do
      @site = Site.make!( preferred_fathom_analytics_tracker_id: "test_fathom_tracker_id" )
      assign( :current_user, User.make! )
      render template: "layouts/bootstrap", locals: { current_user: User.make! }
      expect(rendered).to have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js",
        "data-site": "test_fathom_tracker_id",
        "data-canonical": "false"
      } )
    end

    it "does not include tracker JS if site has a tracker ID, but current user opts out" do
      @site = Site.make!( preferred_fathom_analytics_tracker_id: "test_fathom_tracker_id" )
      render template: "layouts/bootstrap", locals: { current_user: User.make!( prefers_no_tracking: true ) }
      expect(rendered).to_not have_tag( "script", with: {
        src: "https://cdn.usefathom.com/script.js"
      } )
    end
  end
end

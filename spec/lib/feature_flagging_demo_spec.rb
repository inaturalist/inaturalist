# frozen_string_literal: true

require "spec_helper"

# The WEB-1074 demo elements: a badge in the site footer and a banner on
# observation pages, both driven by the single demo_banner flag so one toggle is
# visible through the server-rendered path and the client-side path at once.
# Delete this file with the demo.
describe "the feature flag demo elements", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :badge_text ) { I18n.t( :feature_flag_demo_footer_badge ) }
  # Renders the bootstrap layout, which renders shared/_footer
  let( :path ) { "/observations" }

  describe "the footer badge" do
    it "renders nothing while the flag is off" do
      get path
      expect( response.body ).not_to include badge_text
    end

    # The footer renders on essentially every page in three layouts, so the off
    # state has to emit no markup at all, not merely omit the badge text. The
    # separator count is the sensitive part: a stray separator would leave a
    # dangling "|" in the footer of every page on the site.
    it "emits no extra footer markup while the flag is off" do
      get path
      expect( response.body.scan( "footer-link-separator" ).size ).to eq 2
      expect( response.body ).not_to include "label-info"
    end

    it "emits exactly one extra link and separator when on" do
      Flipper.enable( :demo_banner )
      get path
      expect( response.body.scan( "footer-link-separator" ).size ).to eq 3
      expect( response.body.scan( "label-info" ).size ).to eq 1
    end

    it "appears for an actor the flag is enabled for" do
      user = User.make!
      Flipper.enable_actor( :demo_banner, user )
      sign_in user
      get path
      expect( response.body ).to include badge_text
    end

    it "stays hidden from other logged-in users" do
      Flipper.enable_actor( :demo_banner, User.make! )
      sign_in User.make!
      get path
      expect( response.body ).not_to include badge_text
    end

    it "stays hidden from anonymous visitors while gated to an actor" do
      Flipper.enable_actor( :demo_banner, User.make! )
      get path
      expect( response.body ).not_to include badge_text
    end

    it "appears for everyone once fully enabled" do
      Flipper.enable( :demo_banner )
      get path
      expect( response.body ).to include badge_text
    end
  end

  # The React banner reads CONFIG.feature_flags rather than being rendered by
  # Rails, so what this side has to guarantee is that the resolved value is in
  # the payload at all. app/webpack/shared/feature_flags.test.js covers the
  # reading half.
  describe "the flag map the React banner reads" do
    it "carries the demo flag to the browser" do
      get path
      expect( response.body ).to include %("demo_banner":false)
    end

    it "carries the resolved value per actor" do
      user = User.make!
      Flipper.enable_actor( :demo_banner, user )
      sign_in user
      get path
      expect( response.body ).to include %("demo_banner":true)
    end
  end
end

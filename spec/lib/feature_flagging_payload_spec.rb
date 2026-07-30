# frozen_string_literal: true

require "spec_helper"

# The inline var CONFIG payload is hand-duplicated across three layouts, with no
# shared partial ( extracting it is a WEB-1074 follow-up ). These specs hit one
# real page per layout so a flag map missing from one of them is caught here
# rather than in the browser.
describe "the feature flag payload in layouts", type: :request do
  include Devise::Test::IntegrationHelpers

  # path => the layout it renders
  pages_by_layout = {
    "/observations" => "bootstrap.html.erb",
    "/id_summaries_demo" => "basic.html.haml",
    # Renders errors/error_404 with layout: "application"
    "/pages/help" => "application.html.erb"
  }.freeze

  def rendered_layouts
    seen = []
    subscription = ActiveSupport::Notifications.subscribe( "render_layout.action_view" ) do | *args |
      seen << args.last[:identifier].to_s.split( "/layouts/" ).last
    end
    yield
    seen
  ensure
    ActiveSupport::Notifications.unsubscribe( subscription )
  end

  pages_by_layout.each do | path, layout |
    context "#{path} ( #{layout} )" do
      it "still renders that layout" do
        # Guards the assumption these specs rest on. If a page changes layout,
        # fix the mapping rather than deleting the example.
        expect( rendered_layouts { get path } ).to include layout
      end

      it "includes the flag map for anonymous visitors" do
        get path
        expect( response.body ).to include "feature_flags: {"
        expect( response.body ).to include %("flipper_smoke_test":false)
      end

      it "resolves the flag map per user" do
        user = User.make!
        Flipper.enable_actor( :flipper_smoke_test, user )
        sign_in user
        get path
        expect( response.body ).to include %("flipper_smoke_test":true)
      end

      it "leaves the existing config keys in place" do
        get path
        expect( response.body ).to match( /content_freeze_enabled: (true|false),/ )
      end
    end
  end

  it "covers every layout that emits the payload" do
    layouts_with_payload = Dir[Rails.root.join( "app/views/layouts/**/*" )].
      reject {| f | File.directory?( f ) }.
      select {| f | File.read( f ).include?( "var CONFIG" ) }.
      map {| f | File.basename( f ) }
    expect( layouts_with_payload ).to match_array pages_by_layout.values
  end
end

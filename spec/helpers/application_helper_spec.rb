# frozen_string_literal: true

require "spec_helper"

describe ApplicationHelper do
  describe "hyperlink_mentions" do
    it "links known user mentions in text" do
      User.make!( login: "testmention" )
      str = "Hello @testmention!"
      expect( hyperlink_mentions( str ) ).to eq(
        "Hello <a href=\"http://test.host/people/testmention\">@testmention</a>!"
      )
    end

    it "does not link unknown logins" do
      str = "Hello @testmention!"
      expect( hyperlink_mentions( str ) ).to eq str
    end

    it "links mentions at the start and end of strings" do
      User.make!( login: "alpha" )
      User.make!( login: "beta" )
      str = "@alpha, @beta"
      expect( hyperlink_mentions( str ) ).to eq(
        "<a href=\"http://test.host/people/alpha\">@alpha</a>, " \
          "<a href=\"http://test.host/people/beta\">@beta</a>"
      )
    end

    it "properly links logins that are substrings of each other" do
      User.make!( login: "alpha" )
      User.make!( login: "alphabeta" )
      User.make!( login: "alphabetagamma" )
      str = "Hello @alpha, @alphabeta, @alphabetagamma"
      expect( hyperlink_mentions( str ) ).to eq(
        "Hello <a href=\"http://test.host/people/alpha\">@alpha</a>, " \
          "<a href=\"http://test.host/people/alphabeta\">@alphabeta</a>, " \
          "<a href=\"http://test.host/people/alphabetagamma\">@alphabetagamma</a>"
      )
    end

    it "ignores links that look like mentions" do
      user = create :user
      txt = <<~TXT
        Hey, it's <a rel="me" href="https://foo.bar/@#{user.login}">me</a>
      TXT
      expect( hyperlink_mentions( txt ) ).to eq txt
    end
  end

  describe "formatted_user_text" do
    describe "attribute filtering" do
      it "removes target" do
        formatted = formatted_user_text( '<a target="_blank" href="https://www.inaturalist.org">foo</a>' )
        expect( formatted ).not_to include "target"
        expect( formatted ).not_to include "_blank"
      end
    end
    describe "rel insertion" do
      let( :parsed_formatted_link ) do
        txt = '<a target="_blank" href="https://www.inaturalist.org">foo</a>'
        formatted = formatted_user_text( txt )
        Nokogiri::HTML( formatted ).at( "a" )
      end
      it "adds noopener" do
        expect( parsed_formatted_link[:rel] ).to include "noopener"
      end
      it "adds nofollow" do
        expect( parsed_formatted_link[:rel] ).to include "nofollow"
      end
    end
    describe "mentions" do
      let( :user ) { User.make!( login: "with__extra__underscores" ) }
      it "preserves user logins in mentions" do
        expect( formatted_user_text( "@#{user.login}" ) ).to include( ">@#{user.login}</a>" )
        expect( formatted_user_text( "<p>@#{user.login}</p>" ) ).to include( ">@#{user.login}</a>" )
      end
    end
  end

  describe "#image_url" do
    subject { image_url source, options }

    let( :source ) { "/" }
    let( :options ) { {} }
    let( :assigned_site ) { build :site, url: "https://site-example.org" }
    let( :base_url ) { "http://option-example.org" }

    context "when source is path" do
      let( :source ) { "/source_path" }

      context "with optional base_url" do
        let( :options ) { { base_url: base_url } }

        it do
          is_expected.to eq URI.join(base_url, source).to_s
        end
      end

      context "with site assigned" do
        before { @site = assigned_site }

        it { is_expected.to eq URI.join( assigned_site.url, source ).to_s }
      end

      context "with neither base or site" do
        before { controller.request.host = UrlHelper.root_url }

        it { is_expected.to eq URI.join(UrlHelper.root_url, source).to_s }
      end
    end

    context "when source is whitelisted asset" do
      let( :source ) { "bird.png" }

      context "with optional base_url" do
        let( :options ) { { base_url: base_url } }

        it { is_expected.to eq URI.join( base_url, "/assets/#{source}" ).to_s }
      end

      context "with site assigned" do
        before { @site = assigned_site }

        it { is_expected.to eq URI.join( assigned_site.url, "/assets/#{source}" ).to_s }
      end

      context "with neither base or site" do
        before { controller.request.host = UrlHelper.root_url }

        it { is_expected.to eq URI.join( UrlHelper.root_url, "/assets/#{source}" ).to_s }
      end
    end

    context "when source is asset" do
      let( :source ) { "example_asset.jpg" }

      context "with optional base_url" do
        let( :options ) { { base_url: base_url } }

        it { is_expected.to eq URI.join( base_url, source ).to_s }
      end

      context "with site assigned" do
        before { @site = assigned_site }

        it { is_expected.to eq URI.join( assigned_site.url, source ).to_s }
      end

      context "with neither base or site" do
        before { controller.request.host = UrlHelper.root_url }

        it { is_expected.to eq URI.join( UrlHelper.root_url, source ).to_s }
      end
    end

    context "when source is url" do
      let( :source ) { "http://example.org/asset_path.jpg" }

      context "with optional base_url" do
        let( :options ) { { base_url: base_url } }

        it { is_expected.to eq URI.join( base_url, source ).to_s }
      end

      context "with site assigned" do
        before { @site = assigned_site }

        it { is_expected.to eq URI.join( assigned_site.url, source ).to_s }
      end

      context "with neither base or site" do
        before { controller.request.host = UrlHelper.root_url }

        it { is_expected.to eq URI.join( UrlHelper.root_url, source ).to_s }
      end
    end
  end

  describe "commas_and" do
    describe "default" do
      it "should use commas as separators" do
        expect( commas_and( %w(foo bar baz) ) ).to include( "foo, bar" )
      end
      it "should use and before the last item" do
        expect( commas_and( %w(foo bar baz) ) ).to include( "and baz" )
      end
    end
    # describe "in Hebrew" do
    #   it "should work" do
    #     I18n.with_locale( :es ) do
    #       expect( commas_and( %w(foo bar baz) ) ).to eq( "foo, bar y baz" )
    #     end
    #   end
    # end
  end

  describe "update_tagline_for" do
    include UsersHelper
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "states an observation field value was added" do
      without_delay do
        o = Observation.make!
        ofv = ObservationFieldValue.make!( observation: o, user: User.make! )
        expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
          "#{ofv.user.login} added a value for .* to an observation by #{o.user.login}"
        )
      end
    end

    it "states an observation field value was updated" do
      without_delay do
        o = Observation.make!
        ofv = ObservationFieldValue.make!( observation: o, user: o.user )
        ofv.updater = User.make!
        ofv.save
        expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
          "#{ofv.updater.login} updated a value for .* on an observation by #{o.user.login}"
        )
      end
    end
  end

  describe "create_announcement_impression" do
    let( :ip ) { "127.0.0.1" }
    let( :request ) do
      double(
        "request",
        env: { "REMOTE_ADDR" => ip }
      )
    end

    it "creates announcement impressions for the logged-in user" do
      user = User.make!
      allow_any_instance_of( ApplicationHelper ).to receive( :user_signed_in? ).and_return( true )
      allow_any_instance_of( ApplicationHelper ).to receive( :current_user ).and_return( user )
      allow_any_instance_of( ApplicationHelper ).to receive( :request ).and_return( request )

      announcement = Announcement.make!
      expect( AnnouncementImpression.count ).to eq 0
      create_announcement_impression( announcement )

      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to eq user
      expect( impression.request_ip ).to eq ip
      expect( impression.impressions_count ).to eq 1
    end

    it "creates announcement impressions for the request_ip" do
      allow_any_instance_of( ApplicationHelper ).to receive( :user_signed_in? ).and_return( false )
      allow_any_instance_of( ApplicationHelper ).to receive( :current_user ).and_return( nil )
      allow_any_instance_of( ApplicationHelper ).to receive( :request ).and_return( request )

      announcement = Announcement.make!
      expect( AnnouncementImpression.count ).to eq 0
      create_announcement_impression( announcement )

      expect( AnnouncementImpression.count ).to eq 1
      impression = AnnouncementImpression.first
      expect( impression.announcement ).to eq announcement
      expect( impression.user ).to be_nil
      expect( impression.request_ip ).to eq ip
      expect( impression.impressions_count ).to eq 1
    end
  end
end

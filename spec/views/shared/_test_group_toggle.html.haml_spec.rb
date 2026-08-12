# frozen_string_literal: true

require "spec_helper"

describe "shared/_test_group_toggle" do
  def render_toggle( user, group: "responsive-global" )
    allow( view ).to receive( :current_user ).and_return( user )
    allow( view ).to receive( :logged_in? ).and_return( !user.nil? )
    render partial: "shared/test_group_toggle", locals: { group: group }
  end

  it "renders nothing for anonymous users" do
    render_toggle( nil )
    expect( rendered ).not_to have_tag( "div.TestGroupBanner" )
  end

  describe "for a user who has not joined the group" do
    before { render_toggle( User.make! ) }

    it "prompts them to join, full size" do
      expect( rendered ).to have_tag( "div.TestGroupBanner" ) do
        with_tag "form[action*='join_test'][action*='responsive-global']"
      end
      expect( rendered ).not_to have_tag( "div.TestGroupBanner--compact" )
      expect( rendered ).not_to have_tag( "div.TestGroupBanner .btn-xs" )
    end

    it "does not ask for feedback on a test they are not in" do
      expect( rendered ).not_to have_tag( "a.TestGroupBanner-feedback" )
    end
  end

  describe "for a user already in the group" do
    before do
      user = User.make!
      user.update_column( :test_groups, "responsive-global" )
      render_toggle( user )
    end

    it "offers a way to leave, compactly" do
      expect( rendered ).to have_tag( "div.TestGroupBanner.TestGroupBanner--compact" ) do
        with_tag "form[action*='leave_test'][action*='responsive-global']"
      end
      expect( rendered ).to have_tag( "div.TestGroupBanner .btn-xs" )
    end

    it "links to the feedback survey" do
      expect( rendered ).to have_tag(
        "a.TestGroupBanner-feedback[href='https://inaturalist.typeform.com/to/HZsu49MO'][target='_blank']"
      )
    end
  end

  describe "for a group with no survey of its own" do
    it "renders the banner without a feedback link" do
      I18n.backend.store_translations( :en, surveyless_test_joined_status: "Testing something else" )
      user = User.make!
      user.update_column( :test_groups, "surveyless" )
      render_toggle( user, group: "surveyless" )
      expect( rendered ).to have_tag( "div.TestGroupBanner--compact", text: /Testing something else/ )
      expect( rendered ).not_to have_tag( "a.TestGroupBanner-feedback" )
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

describe "places/new" do
  before do
    assign( :place, Place.new )
  end

  it "lists default requirements for users" do
    user = User.make!
    allow( view ).to receive( :current_user ).and_return( user )
    render
    expect( rendered ).to have_tag( "p", text: t( :places_warning_quota ) )
    expect( rendered ).to have_tag( "p", text: t( :places_warning_observation_count ) )
    expect( rendered ).to have_tag( "p", text: t( :places_warning_area ) )
  end

  it "lists requirements for admins when there is a content freeze" do
    user = User.make!
    allow( view ).to receive( :current_user ).and_return( user )
    allow( CONFIG ).to receive( :content_freeze_enabled ).and_return( true )
    render
    expect( rendered ).to have_tag( "p", text: t( :places_warning_quota ) )
    expect( rendered ).to have_tag( "p",
      text: t( :places_warning_observation_count_during_content_freeze ) )
    expect( rendered ).to have_tag( "p",
      text: t( :places_warning_area_during_content_freeze ) )
  end

  it "lists fewer requirements for admins" do
    user = make_admin
    allow( view ).to receive( :current_user ).and_return( user )
    render
    expect( rendered ).to have_tag( "p", text: t( :places_warning_quota ) )
    expect( rendered ).not_to have_tag( "p", text: t( :places_warning_observation_count ) )
    expect( rendered ).not_to have_tag( "p", text: t( :places_warning_observation_count_during_content_freeze ) )
    expect( rendered ).not_to have_tag( "p", text: t( :places_warning_area ) )
    expect( rendered ).not_to have_tag( "p", text: t( :places_warning_area_during_content_freeze ) )
  end
end

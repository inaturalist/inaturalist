# frozen_string_literal: true

require "spec_helper"

describe "shared/_by_login_header_bootstrap" do
  let( :user ) { User.make! }

  before do
    allow( view ).to receive( :current_user ).and_return( user )
    allow( view ).to receive( :logged_in? ).and_return( true )
  end

  it "renders the legacy header for the responsive variant" do
    render partial: "shared/by_login_header_bootstrap", locals: { user: user }, variants: [:responsive]
    expect( rendered ).to have_tag( ".col-md-12 > h1 .user_image" )
    expect( rendered ).not_to have_tag( ".logged-in-user-image" )
    expect( rendered ).not_to have_tag( "#UserSubnavTabDrawer" )
  end
end

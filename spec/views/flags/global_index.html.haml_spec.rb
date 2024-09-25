# frozen_string_literal: true

require "spec_helper"

describe "flags/index" do
  let( :comment ) { Comment.make!( body: "this is the comment body" ) }

  before do
    flag = Flag.make!( flaggable: comment, flag: "spam" )
    assign( :site, create( :site ) )
    assign( :flag_types, ["spam"] )
    assign( :flags, [flag] )
    assign( :flaggable_type, "Comment" )
  end

  it "shows flaggable content to admins" do
    user = make_admin
    allow( view ).to receive( :current_user ).and_return( user )
    render layout: "layouts/bootstrap", template: "flags/global_index"
    expect( rendered ).to have_tag( "a", text: /Comment/ )
    expect( rendered ).to have_tag( "p", text: /#{comment.body}/ )
  end

  it "shows flaggable content to curators" do
    user = make_curator
    allow( view ).to receive( :current_user ).and_return( user )
    render layout: "layouts/bootstrap", template: "flags/global_index"
    expect( rendered ).to have_tag( "a", text: /Comment/ )
    expect( rendered ).to have_tag( "p", text: /#{comment.body}/ )
  end

  it "does not show flaggable content to non-curators" do
    user = User.make!
    allow( view ).to receive( :current_user ).and_return( user )
    render layout: "layouts/bootstrap", template: "flags/global_index"
    expect( rendered ).not_to have_tag( "a", text: /Comment/ )
    expect( rendered ).not_to have_tag( "p", text: /#{comment.body}/ )
  end
end

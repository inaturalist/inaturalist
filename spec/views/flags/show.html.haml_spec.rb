# frozen_string_literal: true

require "spec_helper"

describe "flags/show" do
  let( :comment ) { Comment.make!( body: "this is the comment body" ) }

  before do
    flag = Flag.make!( flaggable: comment )
    assign( :site, create( :site ) )
    assign( :flag, flag )
    assign( :object, flag.flagged_object )
  end

  it "shows flaggable content to admins" do
    render layout: "layouts/bootstrap", template: "flags/show", locals: { current_user: make_admin }
    expect( rendered ).to have_tag( "h3", text: "Flaggable Content" )
    expect( rendered ).to have_tag( "p", text: /#{comment.body}/ )
  end

  it "shows flaggable content to curators" do
    render layout: "layouts/bootstrap", template: "flags/show", locals: { current_user: make_curator }
    expect( rendered ).to have_tag( "h3", text: "Flaggable Content" )
    expect( rendered ).to have_tag( "p", text: /#{comment.body}/ )
  end

  it "does not show flaggable content to non-curators" do
    render layout: "layouts/bootstrap", template: "flags/show", locals: { current_user: User.make! }
    expect( rendered ).not_to have_tag( "h3", text: "Flaggable Content" )
    expect( rendered ).not_to have_tag( "p", text: /#{comment.body}/ )
  end
end

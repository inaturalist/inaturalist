# frozen_string_literal: true

require "spec_helper"

describe CommentsHelper, type: :helper do
  let( :author ) { User.make! }
  let( :post ) { Post.make!( parent: author, user: author ) }
  let!( :ok ) { Comment.make!( parent: post ) }
  let!( :spam ) { Comment.make!( parent: post ) }

  before { Flag.make!( flaggable: spam, flag: Flag::INAPPROPRIATE ) }

  def visible_for( user )
    allow( helper ).to receive( :current_user ).and_return( user )
    allow( helper ).to receive( :logged_in? ).and_return( !user.nil? )
    helper.visible_comments( post.reload )
  end

  it "hides flagged comments from other users" do
    expect( visible_for( User.make! ) ).to eq [ok]
  end

  it "hides flagged comments from logged-out readers" do
    expect( visible_for( nil ) ).to eq [ok]
  end

  it "shows a flagged comment to its author" do
    expect( visible_for( spam.user ) ).to contain_exactly( ok, spam )
  end

  it "shows flagged comments to curators" do
    expect( visible_for( make_curator ) ).to contain_exactly( ok, spam )
  end
end

# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ModeratorNote, "creation" do
  it "should be possible for a curator" do
    expect( ModeratorNote.make( user: make_curator ) ).to be_valid
  end
  it "should be not be possible for a non-curator" do
    expect( ModeratorNote.make( user: User.make! ) ).not_to be_valid
  end
  it "should not allow body to exceed 750 chars" do
    expect( ModeratorNote.make( body: "what" * 700 ) ).not_to be_valid
  end
end

describe ModeratorNote, "updating" do
  let(:moderator_note) { ModeratorNote.make! }
  it "should be possible if the author is no longer a curator" do
    moderator_note.user.roles.delete_all
    moderator_note.updated_at = Time.now
    expect( moderator_note ).to be_valid
  end
end

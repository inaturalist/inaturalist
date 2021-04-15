require File.dirname(__FILE__) + '/../spec_helper'

describe ModeratorNotesController, "create" do
  let(:subject_user) { User.make! }
  it "should be possible for curators" do
    sign_in make_curator
    expect {
      post :create, moderator_note: { subject_user_id: subject_user.id, body: "darn it" }
    }.to change( ModeratorNote, :count ).by( 1 )
  end
  it "should not be possible for non-curators" do
    sign_in User.make!
    expect {
      post :create, moderator_note: { subject_user_id: subject_user.id, body: "darn it" }
    }.to change( ModeratorNote, :count ).by( 0 )
  end
end

describe ModeratorNotesController, "update" do
  let(:moderator_note) { ModeratorNote.make! }
  it "should be allowed for the author" do
    sign_in moderator_note.user
    new_body = "this is a new body #{Time.now.to_i}"
    patch :update, id: moderator_note.id, moderator_note: { body: new_body }
    moderator_note.reload
    expect( moderator_note.body ).to eq new_body
  end
  it "should be allowed for admins" do
    sign_in make_admin
    new_body = "this is a new body #{Time.now.to_i}"
    patch :update, id: moderator_note.id, moderator_note: { body: new_body }
    moderator_note.reload
    expect( moderator_note.body ).to eq new_body
  end
  it "should not be allowed for other curators" do
    sign_in make_curator
    new_body = "this is a new body #{Time.now.to_i}"
    patch :update, id: moderator_note.id, moderator_note: { body: new_body }
    moderator_note.reload
    expect( moderator_note.body ).not_to eq new_body
  end
end

describe ModeratorNotesController, "destroy" do
  let(:moderator_note) { ModeratorNote.make! }
  it "should be allowed for the author" do
    sign_in moderator_note.user
    delete :destroy, id: moderator_note.id
    expect( ModeratorNote.find_by_id( moderator_note.id ) ).to be_blank
  end
  it "should be allowed for admins" do
    sign_in make_admin
    delete :destroy, id: moderator_note.id
    expect( ModeratorNote.find_by_id( moderator_note.id ) ).to be_blank
  end
  it "should not be allowed for other curators" do
    sign_in make_curator
    delete :destroy, id: moderator_note.id
    expect( ModeratorNote.find_by_id( moderator_note.id ) ).not_to be_blank
  end
end

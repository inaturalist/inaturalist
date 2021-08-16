# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ModeratorNote do
  let(:user) { User.make }
  let(:subject) { ModeratorNote.make(user: user) }

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to(:subject_user).class_name "User" }
  it { is_expected.to validate_length_of(:body).is_at_least(3).is_at_most ModeratorNote::MAX_LENGTH }

  describe "creation" do
    it "should be possible for a curator" do
      expect( ModeratorNote.make( user: make_curator ) ).to be_valid
    end
    it "should be not be possible for a non-curator" do
      expect(subject).not_to be_valid
    end
  end

  describe "updating" do
    let(:moderator_note) { ModeratorNote.make! }
    it "should be possible if the author is no longer a curator" do
      moderator_note.user.roles.delete_all
      moderator_note.updated_at = Time.now
      expect( moderator_note ).to be_valid
    end
  end
end

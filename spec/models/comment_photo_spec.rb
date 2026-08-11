# frozen_string_literal: true

require "spec_helper"

describe CommentPhoto do
  elastic_models( Observation )

  it { is_expected.to belong_to( :comment ).optional.inverse_of( :comment_photos ) }
  it { is_expected.to belong_to :photo }
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :photo }
  it { is_expected.to validate_presence_of :user }

  describe "creation" do
    it "is valid unlinked (no comment) when the user owns the photo" do
      user = User.make!
      cp = CommentPhoto.new( user: user, photo: LocalPhoto.make!( user: user ) )
      expect( cp ).to be_valid
      expect( cp.comment ).to be_nil
    end

    it "requires the photo to be owned by the user" do
      cp = CommentPhoto.new( user: User.make!, photo: LocalPhoto.make!( user: User.make! ) )
      expect( cp ).not_to be_valid
      expect( cp.errors[:photo] ).not_to be_blank
    end
  end

  describe "destruction" do
    it "reaps the photo once it is orphaned" do
      user = User.make!
      photo = LocalPhoto.make!( user: user )
      CommentPhoto.create!( user: user, photo: photo ).destroy
      Delayed::Worker.new.work_off
      expect( Photo.find_by_id( photo.id ) ).to be_blank
    end
  end
end

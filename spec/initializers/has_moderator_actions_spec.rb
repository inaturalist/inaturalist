# frozen_string_literal: true

require "spec_helper"

describe Comment do

  let( :comment ) { Comment.make! }

  describe "hideable_by?" do
    it "should not be hideable by the creator" do
      expect( comment.hideable_by?( comment.user ) ).to eq false
    end

    it "should not be hideable by a non-curator" do
      expect( comment.hideable_by?( User.make! ) ).to eq false
    end

    it "should be hideable by a curator" do
      expect( comment.hideable_by?( make_curator ) ).to eq true
    end

    it "should be hideable by an admin" do
      expect( comment.hideable_by?( make_admin ) ).to eq true
    end
  end

  describe "hidden_content_viewable_by?" do
    it "should be viewable by the creator" do
      expect( comment.hidden_content_viewable_by?( comment.user ) ).to eq true
    end

    it "should not be viewable by a non-curator" do
      expect( comment.hidden_content_viewable_by?( User.make! ) ).to eq false
    end

    it "should be viewable by a curator" do
      expect( comment.hidden_content_viewable_by?( make_curator ) ).to eq true
    end

    it "should be viewable by an admin" do
      expect( comment.hidden_content_viewable_by?( make_admin ) ).to eq true
    end
  end
end

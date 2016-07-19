require File.dirname(__FILE__) + '/../spec_helper'

describe FlagsController do

  # These are crazy simple tests, but we do rely on the values of these
  # constants elsewhere, so I figured some tests couldn't hurt
  it "should have the right FLAG_MODELS" do
    expect( FlagsController::FLAG_MODELS ).to eq [ "Observation", "Taxon", "Post", "Comment",
      "Identification", "Message", "Photo", "List", "Project", "Guide", "GuideSection", "LifeList",
      "User", "CheckList" ]
  end

  it "should have the right FLAG_MODELS_ID" do
    expect( FlagsController::FLAG_MODELS_ID ).to eq [ "observation_id", "taxon_id", "post_id",
      "comment_id", "identification_id", "message_id", "photo_id", "list_id", "project_id",
      "guide_id", "guide_section_id", "life_list_id", "user_id", "check_list_id"]
  end

  describe "update" do
    let(:curator) { make_curator }
    let(:user) { make_curator }
    let(:flag) { Flag.make!(flaggable: Photo.make!, user: user) }

    it "allows curators to update" do
      http_login(curator)
      post :update, id: flag.id, flag: { comment: "whatever" }
      expect(flash[:error]).to be_blank
    end

    it "allows the flag creator to update" do
      http_login(user)
      post :update, id: flag.id, flag: { comment: "whatever" }
      expect(flash[:error]).to be_blank
    end

    it "does not allow other users to update" do
      http_login(User.make!)
      post :update, id: flag.id, flag: { comment: "whatever" }
      expect(flash[:error]).to eq "You don't have permission to do that."
    end
  end

  describe "destroy" do
    let(:curator) { make_curator }
    let(:user) { make_curator }
    let(:flag) { Flag.make!(flaggable: Photo.make!, user: user) }

    it "allows curators to update" do
      http_login(curator)
      post :destroy, id: flag.id
      expect(flash[:error]).to be_blank
    end

    it "allows the flag creator to update" do
      http_login(user)
      post :destroy, id: flag.id
      expect(flash[:error]).to be_blank
    end

    it "does not allow other users to update" do
      http_login(User.make!)
      post :destroy, id: flag.id
      expect(flash[:error]).to eq "You don't have permission to do that."
    end
  end

end

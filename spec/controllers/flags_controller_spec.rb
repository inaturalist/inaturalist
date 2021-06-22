require File.dirname(__FILE__) + '/../spec_helper'

describe FlagsController do

  # These are crazy simple tests, but we do rely on the values of these
  # constants elsewhere, so I figured some tests couldn't hurt
  it "should have the right FLAG_MODELS" do
    expect( FlagsController::FLAG_MODELS ).to eq [ "Observation", "Taxon", "Post", "Comment",
      "Identification", "Message", "Photo", "List", "Project", "Guide", "GuideSection",
      "User", "CheckList", "Sound" ]
  end

  it "should have the right FLAG_MODELS_ID" do
    expect( FlagsController::FLAG_MODELS_ID ).to eq [ "observation_id", "taxon_id", "post_id",
      "comment_id", "identification_id", "message_id", "photo_id", "list_id", "project_id",
      "guide_id", "guide_section_id", "user_id", "check_list_id", "sound_id" ]
  end

  describe "update" do
    elastic_models( Observation )

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

    it "should succeed when resolving a flag on a deleted observation" do
      o = Observation.make!
      flag = Flag.make!( flaggable: o )
      o.destroy
      http_login curator
      post :update, id: flag.id, flag: {
        comment: "it's fine, everything's fine, totally fine",
        resolver_id: curator.id,
        resolved: true
      }
      expect( response ).to be_redirect
      flag.reload
      expect( flag ).to be_resolved
    end
  end

  describe "destroy" do
    elastic_models( Observation )
    
    let(:curator) { make_curator }
    let(:user) { make_curator }
    let(:admin) { make_admin }
    let(:flag) { Flag.make!(flaggable: Photo.make!, user: user) }

    it "does not allow curators to destroy" do
      http_login(curator)
      post :destroy, id: flag.id
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "does not allow the flag creator to destroy if there are comments" do
      http_login(user)
      Comment.make!( parent: flag )
      post :destroy, id: flag.id
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "does not allow the flag creator to destroy if resolved" do
      http_login( user )
      flag.update_attributes( resolved: true, resolver: make_curator )
      post :destroy, id: flag.id
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "allows the flag creator to destroy if unresolved and there are no comments" do
      http_login( user )
      expect( flag.comments.count ).to eq 0
      expect( flag ).not_to be_resolved
      post :destroy, id: flag.id
      expect( Flag.find_by_id( flag.id ) ).to be_blank
    end

    it "does not allow other users to destroy" do
      http_login(User.make!)
      post :destroy, id: flag.id
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "allows admins to destroy" do
      http_login( admin )
      post :destroy, id: flag.id
      expect( Flag.find_by_id( flag.id ) ).to be_blank
    end
  end

end

require File.dirname(__FILE__) + '/../spec_helper'

describe FlagsController do

  describe "update" do
    elastic_models( Observation )

    let(:curator) { make_curator }
    let(:user) { make_curator }
    let(:flag) { Flag.make!(flaggable: Photo.make!, user: user) }

    it "allows curators to update" do
      http_login(curator)
      post :update, params: { id: flag.id, flag: { comment: "whatever" } }
      expect(flash[:error]).to be_blank
    end

    it "allows the flag creator to update" do
      http_login(user)
      post :update, params: { id: flag.id, flag: { comment: "whatever" } }
      expect(flash[:error]).to be_blank
    end

    it "does not allow other users to update" do
      http_login(User.make!)
      post :update, params: { id: flag.id, flag: { comment: "whatever" } }
      expect(flash[:error]).to eq "You don't have permission to do that."
    end

    it "should succeed when resolving a flag on a deleted observation" do
      o = Observation.make!
      flag = Flag.make!( flaggable: o )
      o.destroy
      http_login curator
      post :update, params: { id: flag.id, flag: {
        comment: "it's fine, everything's fine, totally fine",
        resolver_id: curator.id,
        resolved: true
      } }
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
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "does not allow the flag creator to destroy if there are comments" do
      http_login(user)
      Comment.make!( parent: flag )
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "does not allow the flag creator to destroy if resolved" do
      http_login( user )
      flag.update_attributes( resolved: true, resolver: make_curator )
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "allows the flag creator to destroy if unresolved and there are no comments" do
      http_login( user )
      expect( flag.comments.count ).to eq 0
      expect( flag ).not_to be_resolved
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).to be_blank
    end

    it "does not allow other users to destroy" do
      http_login(User.make!)
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "allows admins to destroy" do
      http_login( admin )
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).to be_blank
    end
  end

end

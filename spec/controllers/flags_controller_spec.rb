# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe FlagsController do
  describe "create" do
    let( :taxon ) { Taxon.make! }
    let( :user ) { User.make! }
    it "should add an initial comment to a flag if it is submitted with the flag" do
      sign_in( user )
      first_comment = "first comment"
      post :create, format: :json, params: {
        flag: { flaggable_type: "Taxon",
                flaggable_id: taxon.id,
                flag: "some flag",
                initial_comment_body: first_comment }
      }
      expect( response.status ).to eq 200
      taxon.reload
      expect( taxon.flags.first.comments.size ).to eq 1
      expect( taxon.flags.first.comments.first.body ).to eq first_comment
    end
    it "should save a flag even if the submitted initial comment is invalid" do
      sign_in( user )
      long_comment = "abcdef" * 1000 # This comment is too long, 6000 characters. The limit is 5000.
      post :create, format: :json, params: {
        flag: { flaggable_type: "Taxon",
                flaggable_id: taxon.id,
                flag: "a different flag",
                initial_comment_body: long_comment }
      }
      expect( response.status ).to eq 200
      taxon.reload
      expect( taxon.flags.first.comments.size ).to eq 0
      expect( flash[:notice] ).to eq "Flag saved. Thanks! <a href=\"http://test.host/flags/2\" class=\"readmore\">View flag</a> Unfortunately, we were unable to save the comment."
    end
  end

  describe "update" do
    elastic_models( Observation )

    let( :curator ) { make_curator }
    let( :user ) { make_curator }
    let( :flag ) { Flag.make!( flaggable: Photo.make!, user: user ) }

    it "allows curators to update" do
      sign_in( curator )
      post :update, params: { id: flag.id, flag: { comment: "whatever" } }
      expect( flash[:error] ).to be_blank
    end

    it "allows the flag creator to update" do
      sign_in( user )
      post :update, params: { id: flag.id, flag: { comment: "whatever" } }
      expect( flash[:error] ).to be_blank
    end

    it "does not allow other users to update" do
      sign_in( User.make! )
      post :update, params: { id: flag.id, flag: { comment: "whatever" } }
      expect( flash[:error] ).to eq "You don't have permission to do that."
    end

    it "should succeed when resolving a flag on a deleted observation" do
      o = Observation.make!
      flag = Flag.make!( flaggable: o )
      o.destroy
      sign_in curator
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

    let( :curator ) { make_curator }
    let( :user ) { make_curator }
    let( :admin ) { make_admin }
    let( :flag ) { Flag.make!( flaggable: Photo.make!, user: user ) }

    it "does not allow curators to destroy" do
      sign_in( curator )
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "does not allow the flag creator to destroy if there are comments" do
      sign_in( user )
      Comment.make!( parent: flag )
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "does not allow the flag creator to destroy if resolved" do
      sign_in( user )
      flag.update( resolved: true, resolver: make_curator )
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "allows the flag creator to destroy if unresolved and there are no comments" do
      sign_in( user )
      expect( flag.comments.count ).to eq 0
      expect( flag ).not_to be_resolved
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).to be_blank
    end

    it "does not allow other users to destroy" do
      sign_in( User.make! )
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).not_to be_blank
    end

    it "allows admins to destroy" do
      sign_in( admin )
      post :destroy, params: { id: flag.id }
      expect( Flag.find_by_id( flag.id ) ).to be_blank
    end
  end
end

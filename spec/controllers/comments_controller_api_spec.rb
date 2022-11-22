require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a CommentsController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make! }

  describe "create" do
    it "should work" do
      expect(observation.comments.count).to eq 0
      post :create, format: :json, params: { comment: {
        parent_type: "Observation",
        parent_id: observation.id,
        body: "i must eat them all"
      } }
      observation.reload
      expect(observation.comments.count).to eq 1
    end

    it "should error out for invalid comments" do
      post :create, format: :json, params: { comment: {
        parent_type: "Observation",
        body: "this is erroneous!"
      } }
      expect(response.status).to eq 422
    end

    it "should assign an observation as a parent by UUID" do
      post :create, format: :json, params: { comment: {
        parent_type: "Observation",
        parent_id: observation.uuid,
        body: "polymorphism ruins everything"
      } }
      observation.reload
      expect( observation.comments.size ).to eq 1
    end

    it "should not work if the parent prefers no comments" do
      user = User.make!
      parent = Post.make!( prefers_no_comments: true, parent: user, user: user )
      post :create, format: :json, params: { comment: {
        parent_type: "Post",
        parent_id: parent.id,
        body: "what a terrible post"
      } }
      parent.reload
      expect( parent.comments.size ).to eq 0
    end
  end

  describe "update" do
    let(:comment) { Comment.make!( user: user ) }
    it "should work" do
      expect(comment.body).not_to be_blank
      expect {
        put :update, format: :json, params: { id: comment.id, comment: { body: "i must eat them all" } }
        comment.reload
      }.to change(comment, :body)
    end
    it "should not work if the comment is hidden" do
      ModeratorAction.make!( resource: comment )
      comment.reload
      expect( comment ).to be_hidden
      expect {
        put :update, format: :json, params: { id: comment.id, comment: { body: "i must eat them all" } }
        comment.reload
      }.not_to change(comment, :body)
    end
  end

  describe "destroy" do
    let(:comment) { Comment.make!( user: user ) }
    it "should work" do
      delete :destroy, params: { id: comment.id }
      expect( Comment.find_by_id( comment.id ) ).to be_blank
    end
    it "should not work if the comment is hidden" do
      ModeratorAction.make!( resource: comment )
      comment.reload
      expect( comment ).to be_hidden
      delete :destroy, params: { id: comment.id }
      expect( Comment.find_by_id( comment.id ) ).not_to be_blank
    end
  end
end

describe CommentsController, "oauth authentication" do
  let(:token) { double acceptable?: true, accessible?: true, resource_owner_id: user.id, application: OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a CommentsController"
end

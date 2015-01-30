require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a CommentsController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make! }

  describe "create" do
    it "should work" do
      observation.comments.count.should eq 0
      post :create, :format => :json, :comment => {
        :parent_type => "Observation",
        :parent_id => observation.id,
        :body => "i must eat them all"
      }
      observation.reload
      observation.comments.count.should eq 1
    end

    it "should error out for invalid comments" do
      post :create, :format => :json, :comment => {
        :parent_type => "Observation",
        :body => "this is erroneous!"
      }
      response.status.should == 422
    end
  end

  describe "update" do
    let(:comment) { Comment.make!(:user => user) }
    it "should work" do
      comment.body.should_not be_blank
      lambda {
        put :update, :format => :json, :id => comment.id, :comment => {:body => "i must eat them all"}
        comment.reload
      }.should change(comment, :body)
    end
  end

  describe "destroy" do
    let(:comment) { Comment.make!(:user => user) }
    it "should work" do
      delete :destroy, :format => :json, :id => comment.id
      Comment.find_by_id(comment.id).should be_blank
    end
  end
end

describe CommentsController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "a CommentsController"
end

describe CommentsController, "devise authentication" do
  before { http_login(user) }
  it_behaves_like "a CommentsController"
end

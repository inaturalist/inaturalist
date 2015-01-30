require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an ObservationPhotosController" do
  describe "create" do
    let(:file) { fixture_file_upload('files/egg.jpg', 'image/jpeg') }
    it "should work" do
      lambda {
        post :create, :format => :json, :observation_photo => {:observation_id => observation.id}, :file => file
      }.should change(ObservationPhoto, :count).by(1)
      response.should be_success
    end

    it "should not duplicate observation photos with the same uuid" do
      uuid = "some really long identifier"
      op = ObservationPhoto.make!(:uuid => uuid, :observation => observation)
      post :create, :format => :json, :observation_photo => {:observation_id => observation.id, :uuid => uuid}, :file => file
      ObservationPhoto.where(:uuid => uuid).count.should eq 1
    end
  end

  it "should update" do
    p = LocalPhoto.make!(:user => user)
    op = ObservationPhoto.make!(:photo => p, :observation => observation)
    op.position.should be_blank
    put :update, :format => :json, :id => op.id, :observation_photo => {:position => 1}
    response.should be_success
    op.reload
    op.position.should eq(1)
  end

  it "should destroy" do
    p = LocalPhoto.make!(:user => user)
    op = ObservationPhoto.make!(:photo => p, :observation => observation)
    delete :destroy, :format => :json, :id => op.id
    ObservationPhoto.find_by_id(op.id).should be_blank
  end
end

describe ObservationPhotosController, "oauth authentication" do
  let(:user) { User.make! }
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  let(:observation) { Observation.make!(:user => user)}
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "an ObservationPhotosController"
end

describe ObservationPhotosController, "devise authentication" do
  let(:user) { User.make! }
  let(:observation) { Observation.make!(:user => user)}
  before do
    http_login user
  end
  it_behaves_like "an ObservationPhotosController"
end

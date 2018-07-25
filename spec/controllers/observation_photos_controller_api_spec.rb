require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an ObservationPhotosController" do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }

  describe "create" do
    let(:file) { fixture_file_upload('files/cuthona_abronia-tagged.jpg', 'image/jpeg') }
    it "should work" do
      expect {
        post :create, :format => :json, :observation_photo => {:observation_id => observation.id}, :file => file
      }.to change(ObservationPhoto, :count).by(1)
      expect(response).to be_success
    end

    it "should not duplicate observation photos with the same uuid" do
      uuid = "some really long identifier"
      op = make_observation_photo(:uuid => uuid, :observation => observation)
      post :create, :format => :json, :observation_photo => {:observation_id => observation.id, :uuid => uuid}, :file => file
      expect(ObservationPhoto.where(:uuid => uuid).count).to eq 1
      observation.reload
      expect(observation.photos.size).to eq 1
    end

    it "should not include photo metadata" do
      op = make_observation_photo( observation: observation )
      post :create, format: :json, observation_photo: { observation_id: observation.id }, file: file
      json = JSON.parse( response.body )
      expect( json["photo"] ).not_to be_blank
      expect( json["photo"].keys ).not_to include "metadata"
    end

    it "should not allow adding a photo by another user" do
      other_o = make_research_grade_observation
      other_p = other_o.photos.first
      post :create, format: :json, observation_photo: { observation_id: observation.id, photo_id: other_p.id }
      expect( response.status ).to eq 403
      observation.reload
      expect( observation.photos ).to be_blank
    end

    describe "observation" do
      before(:each) { enable_elastic_indexing( Identification ) }
      after(:each) { disable_elastic_indexing( Identification ) }
      before(:all) { DatabaseCleaner.strategy = :truncation }
      after(:all)  { DatabaseCleaner.strategy = :transaction }

      it "should change quality_grade from casual to needs_id" do
        o = Observation.make!( user: user, observed_on_string: "2018-05-02", latitude: 1, longitude: 1 )
        expect( o.quality_grade ).to eq Observation::CASUAL
        post :create, format: :json, observation_photo: { observation_id: o.id }, file: file
        o.reload
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      it "should change quality_grade in the observations index" do
        o = Observation.make!( user: user, observed_on_string: "2018-05-02", latitude: 1, longitude: 1 )
        expect(
          Observation.elastic_search( where: { id: o.id } ).results.results.first.quality_grade
        ).to eq Observation::CASUAL
        post :create, format: :json, observation_photo: { observation_id: o.id }, file: file
        o.reload
        expect(
          Observation.elastic_search( where: { id: o.id } ).results.results.first.quality_grade
        ).to eq Observation::NEEDS_ID
      end
    end
  end

  describe "update" do
    it "should work" do
      p = LocalPhoto.make!(:user => user)
      op = make_observation_photo(:photo => p, :observation => observation)
      expect(op.position).to be_blank
      put :update, :format => :json, :id => op.id, :observation_photo => {:position => 1}
      expect(response).to be_success
      op.reload
      expect(op.position).to eq(1)
    end
    describe "when the observation photo does not exist" do
      let(:file) { fixture_file_upload('files/cuthona_abronia-tagged.jpg', 'image/jpeg') }
      it "should create an observation photo" do
        o = Observation.make!( user: user )
        expect( o.observation_photos.size ).to eq 0
        put :update, format: :json, id: nil, observation_photo: { observation_id: o.id }, file: file
        expect( response ).to be_success
        o.reload
        expect( o.observation_photos.size ).to eq 1
      end
      it "should not create an observation photo if the user does not own the observation" do
        o = Observation.make!
        expect( o.observation_photos.size ).to eq 0
        put :update, format: :json, id: nil, observation_photo: { observation_id: o.id }, file: file
        expect( response ).not_to be_success
        expect( response.code ).not_to eq 500
        o.reload
        expect( o.observation_photos.size ).to eq 0
      end
    end
    it "should return an error when you try to update an observation photo that isn't yours" do
      op = make_observation_photo
      put :update, format: :json, id: op.id, observation_photo: { observation_id: op.observation_id, position: 2 }
      expect( response ).not_to be_success
      expect( response.code ).not_to eq 500
      json = JSON.parse( response.body )
      expect( json["error"] ).not_to be_blank
    end
  end

  describe "destroy" do
    it "should destroy" do
      p = LocalPhoto.make!(:user => user)
      op = make_observation_photo(:photo => p, :observation => observation)
      delete :destroy, :format => :json, :id => op.id
      expect(ObservationPhoto.find_by_id(op.id)).to be_blank
    end
    it "should return 403 Forbidden if user doesn't own the observation" do
      op = make_observation_photo
      delete :destroy, format: :json, id: op.id
      expect( response.status ).to eq 403
    end
  end

end

describe ObservationPhotosController, "oauth authentication" do
  let(:user) { User.make! }
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  let(:observation) { Observation.make!(:user => user)}
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
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

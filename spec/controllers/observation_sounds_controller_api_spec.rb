require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an ObservationSoundsController" do
  describe "create" do
    let(:file) { fixture_file_upload( "files/pika.mp3", "audio/mpeg" ) }
    it "should work" do
      expect {
        post :create, format: :json, observation_sound: { observation_id: observation.id }, file: file
      }.to change( ObservationSound, :count ).by( 1 )
      expect( response ).to be_success
    end
  end
end

describe ObservationSoundsController, "oauth authentication" do
  let(:user) { User.make! }
  let(:token) { double :acceptable? => true, accessible?: true, resource_owner_id: user.id }
  let(:observation) { Observation.make!( user: user ) }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "an ObservationSoundsController"
end

describe ObservationSoundsController, "devise authentication" do
  let(:user) { User.make! }
  let(:observation) { Observation.make!( user: user ) }
  before do
    http_login user
  end
  it_behaves_like "an ObservationSoundsController"
end

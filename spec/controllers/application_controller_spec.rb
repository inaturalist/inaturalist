require 'spec_helper'

describe ApplicationController do
  render_views

  describe "UnknownFormat" do
    # I'm testing a feature implemented in the ApplicationController by using
    # the ObservationsController since there are no testable public-facing
    # actions in the ApplicationController
    describe ObservationsController do
      before(:each) { enable_elastic_indexing([ Observation ]) }
      after(:each) { disable_elastic_indexing([ Observation ]) }

      it "render the 404 page for unknown formats" do
        get :index, format: :html
        expect(response.response_code).to eq 200
        expect(response.body).to include "Observations"
        get :index, format: :mobile
        expect(response.response_code).to eq 200
        expect(response.body).to include "Observations"
        get :index, format: :json
        expect(response.response_code).to eq 200
        expect(JSON.parse response.body).to eq [ ]
        get :index, format: :nonsense
        expect(response.response_code).to eq 404
        expect(response.body).to include "Sorry, that doesn't exist!"
      end
    end
  end

end

require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a QualityMetricsController" do
  let(:user) { User.make! }

  describe "vote" do
    let(:o) { Observation.make! }

    describe "route" do
      it "should accept POST requests" do
        expect( post: "observations/#{o.id}/quality/#{QualityMetric::WILD}" ).to be_routable
      end
      it "should accept POST requests" do
        expect( delete: "observations/#{o.id}/quality/#{QualityMetric::WILD}" ).to be_routable
      end
    end

    it "should create a QualityMetric in response to POST" do
      expect {
        post :vote, format: :json, id: o.id, metric: QualityMetric::WILD, agree: "true"
      }.to change( QualityMetric, :count ).by( 1 )
    end
    it "should set agree to true if true" do
      post :vote, format: :json, id: o.id, metric: QualityMetric::WILD, agree: "true"
      expect( o.quality_metrics.last ).to be_agree
    end
    it "should set agree to false if false" do
      post :vote, format: :json, id: o.id, metric: QualityMetric::WILD, agree: "false"
      expect( o.quality_metrics.last ).not_to be_agree
    end
    it "should destroy an existing QualityMetric in response to DELETE" do
      qm = QualityMetric.make!( user: user, observation: o, metric: QualityMetric::WILD, agree: true)
      delete :vote, format: :json, id: o.id, metric: QualityMetric::WILD
      expect( QualityMetric.find_by_id( qm.id ) ).to be_nil
      o.reload
      expect( o.quality_metrics ).to be_blank
    end

    describe "elastic index" do
      before(:each) { enable_elastic_indexing( Observation ) }
      after(:each) { disable_elastic_indexing( Observation ) }

      it "should get the updated quality_grade" do
        o = without_delay { make_research_grade_observation }
        o.elastic_index!
        eo = Observation.elastic_search( where: { id: o.id } ).results[0]
        expect( eo.id.to_i ).to eq o.id
        expect( eo.quality_grade ).to eq Observation::RESEARCH_GRADE
        without_delay do
          post :vote, format: :json, id: o.id, metric: QualityMetric::WILD, agree: "false"
        end
        eo = Observation.elastic_search( where: { id: o.id } ).results[0]
        expect( eo.quality_grade ).to eq Observation::CASUAL
      end
    end
  end

end

describe QualityMetricsController, "oauth authentication" do
  let(:token) do
    double acceptable?: true,
      accessible?: true,
      resource_owner_id: user.id,
      application: OauthApplication.make!
  end
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a QualityMetricsController"
end

describe QualityMetricsController, "devise authentication" do
  before { http_login(user) }
  it_behaves_like "a QualityMetricsController"
end

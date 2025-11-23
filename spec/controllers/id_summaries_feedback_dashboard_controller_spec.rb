require File.dirname(__FILE__) + "/../spec_helper"

describe IdSummariesFeedbackDashboardController do
  describe "GET index" do
    let(:admin) { make_admin }
    let(:voter_positive) { User.make! }
    let(:voter_negative) { User.make! }
    let(:voter_identification) { User.make! }
    let!(:taxon_summary) do
      TaxonIdSummary.create!(
        uuid: SecureRandom.uuid,
        active: true,
        taxon_id: 1,
        taxon_name: "Test taxon",
        language: "en",
        run_name: "demo_run"
      )
    end
    let!(:id_summary) do
      IdSummary.create!(
        taxon_id_summary: taxon_summary,
        summary: "Sample text",
        visual_key_group: "general"
      )
    end

    before do
      IdSummaryDqa.create!( id_summary: id_summary, user: voter_positive, metric: IdSummaryDqa::TRUE, agree: true )
      IdSummaryDqa.create!( id_summary: id_summary, user: voter_negative, metric: IdSummaryDqa::TRUE, agree: false )
      IdSummaryDqa.create!( id_summary: id_summary, user: voter_identification, metric: IdSummaryDqa::IDENTIFICATION, agree: true )
    end

    it "aggregates feedback counts for each metric" do
      sign_in admin
      get :index, params: { run_name: "demo" }
      expect( response ).to be_successful
      rows = assigns( :taxon_feedback )
      expect( rows.size ).to eq 1
      row = rows.first
      expect( row["positive_total"] ).to eq 2
      expect( row["negative_total"] ).to eq 1
      expect( row["true_positive"] ).to eq 1
      expect( row["true_negative"] ).to eq 1
      expect( row["identification_positive"] ).to eq 1
    end
  end
end

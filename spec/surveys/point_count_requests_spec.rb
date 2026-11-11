# frozen_string_literal: true

require_relative "survey_spec_helper"
require_relative "point_count_spec_helpers"

RSpec.describe "Private point-count pages", type: :request do
  include PointCountSpecHelpers
  include Devise::Test::IntegrationHelpers
  before { prepare_point_count }
  let( :workflow ) { Surveys::PointCount.new( survey_user ) }
  let( :event ) { workflow.create( station_fields ) }

  it "requires authentication" do
    get "/point_counts"
    expect( response ).to redirect_to new_user_session_path
  end

  it "runs the full HTML workflow including evidence, completion, repeat visits and voiding" do
    sign_in survey_user
    get "/point_counts/new"
    expect( response ).to have_http_status :ok
    expect( response.body ).to include "Field instructions"
    post "/point_counts", params: { point_count: station_fields }
    visit = workflow.events.first!
    expect( response ).to redirect_to edit_point_count_path( visit.uuid )
    follow_redirect!
    expect( response.body ).to include "Save effort and assessment"
    patch point_count_path( visit.uuid ), params: { point_count: effort_fields }
    expect( response ).to have_http_status :found
    post add_detection_point_count_path( visit.uuid ), params: { point_count: detection_fields }
    expect( response ).to have_http_status :found
    post complete_point_count_path( visit.uuid )
    expect( response ).to redirect_to point_count_path( visit.uuid )
    follow_redirect!
    expect( response.body ).to include "Completed", "Aves", "New visit at this station"
    expect( response.headers["Cache-Control"] ).to include "no-store"
    expect( response.headers["Referrer-Policy"] ).to eq "same-origin"
    expect( response.body ).not_to include "googletagmanager", "google-analytics"
    post void_point_count_path( visit.uuid ), params: { point_count: { reason: "Incorrect station" } }
    expect( visit.reload.status ).to eq "void"
  end

  it "returns 404 for another owner's private pages and every mutation" do
    uuid = event.uuid
    stranger = another_user
    event.survey_event_participants.create!( user: stranger, role: "observer" )
    sign_in stranger
    [point_count_path( uuid ), edit_point_count_path( uuid )].each do | path |
      get path
      expect( response ).to have_http_status :not_found
      expect( response.body ).not_to include "Pond North", "42.4"
    end
    patch point_count_path( uuid ), params: { point_count: effort_fields }
    expect( response ).to have_http_status :not_found
    [:add_detection, :remove_detection, :complete, :void].each do | action |
      post "/point_counts/#{uuid}/#{action}", params: { point_count: detection_fields }
      expect( response ).to have_http_status :not_found
    end
    get point_counts_path
    expect( response.body ).not_to include "Pond North"
  end

  it "ignores ownership, privacy and lifecycle mass assignment" do
    sign_in survey_user
    post point_counts_path, params: { point_count: station_fields.merge( "user_id" => another_user.id,
      "location_privacy" => "public", "status" => "completed", "protocol_version_id" => 123 ) }
    visit = workflow.events.first!
    expect( visit.user_id ).to eq survey_user.id
    expect( visit.location_privacy ).to eq "private"
    expect( visit.status ).to eq "in_progress"
  end

  it "does not provide a JSON disclosure path and preserves draft data on errors" do
    sign_in survey_user
    get point_count_path( event.uuid, format: :json )
    expect( response ).to have_http_status :not_acceptable
    patch point_count_path( event.uuid ), params: { point_count: effort_fields.merge( "wind" => "invalid" ) }
    expect( response ).to have_http_status :unprocessable_entity
    expect( event.reload.started_at ).to be_nil
  end

  it "accepts the signed form from its own origin but rejects foreign and null origins" do
    sign_in survey_user
    original = PointCountsController.allow_forgery_protection
    original_check = PointCountsController.forgery_protection_origin_check
    PointCountsController.allow_forgery_protection = true
    PointCountsController.forgery_protection_origin_check = true
    get new_point_count_path
    expect( response.headers["Referrer-Policy"] ).to eq "same-origin"
    token = Nokogiri::HTML( response.body ).at_css( 'form input[name="authenticity_token"]' )["value"]
    payload = { point_count: station_fields, authenticity_token: token }
    origin = request.base_url
    ["null", "https://other.example"].each do | other |
      expect do
        post point_counts_path, params: payload, headers: { "Origin" => other }
      end.not_to change( SurveyEvent, :count )
      expect( response ).to have_http_status :unprocessable_entity
    end
    expect do
      post point_counts_path, params: payload, headers: { "Origin" => origin }
    end.to change( SurveyEvent, :count ).by( 1 )
  ensure
    PointCountsController.allow_forgery_protection = original
    PointCountsController.forgery_protection_origin_check = original_check
  end

  it "requires CSRF tokens even when an Authorization header is supplied" do
    sign_in survey_user
    original = PointCountsController.allow_forgery_protection
    PointCountsController.allow_forgery_protection = true
    expect do
      post point_counts_path, params: { point_count: station_fields }, headers: { "Authorization" => "irrelevant" }
    end.not_to change( SurveyEvent, :count )
    expect( response ).to have_http_status :unprocessable_entity
  ensure
    PointCountsController.allow_forgery_protection = original
  end
end

# frozen_string_literal: true

require_relative "survey_spec_helper"

require_relative "point_count_spec_helpers"

RSpec.describe Surveys::PointCount do
  include PointCountSpecHelpers
  before { prepare_point_count }
  let( :workflow ) { described_class.new( survey_user ) }
  let( :event ) { workflow.create( station_fields ) }

  it "installs one immutable version, including structured radius and detection definitions" do
    expect { prepare_point_count }.not_to change( SurveyProtocol, :count )
    version = Surveys::PointCountProtocol.version
    expect( version.status ).to eq "published"
    expect( version.survey_measurement_definitions.find_by!( field_key: "radius_meters" ).validation_rules ).to eq(
      "min" => 50, "max" => 50
    )
    expect( version.update( instructions: "Changed" ) ).to be false
  end

  it "creates private station snapshots and reuses the station for a repeat visit" do
    first = event
    second = workflow.create( "station_uuid" => first.survey_sampling_unit.uuid )
    expect( second.survey_sampling_unit_id ).to eq first.survey_sampling_unit_id
    expect( second.id ).not_to eq first.id
    expect( first.location_privacy ).to eq "private"
    expect( first.geom.x ).to eq( -71.1 )
    expect( first.survey_event_participants.first.user_id ).to eq survey_user.id
  end

  it "completes a zero-detection visit without generating absences" do
    workflow.update( event.uuid, effort_fields )
    completed = workflow.complete( event.uuid )
    expect( completed.status ).to eq "completed"
    expect( completed.completion_status ).to eq "complete"
    expect( completed.survey_efforts.first.duration_seconds ).to eq 300
    expect( completed.survey_detections ).to be_empty
    expect( completed.survey_event_targets.first.absence_reporting ).to be false
  end

  it "keeps an interrupted visit and distinguishes complete reporting from method compliance" do
    fields = effort_fields.merge( "ended_at" => "2026-10-25T07:13:00", "method_followed" => "false",
      "deviation_reason" => "Interrupted by construction" )
    workflow.update( event.uuid, fields )
    completed = workflow.complete( event.uuid )
    expect( completed.completion_status ).to eq "complete"
    expect( completed.survey_efforts.first.duration_seconds ).to eq 180
    expect( described_class.values( completed )["method_followed"] ).to be false
  end

  it "rejects a false compliance claim and requires a deviation reason" do
    workflow.update( event.uuid, effort_fields.merge( "ended_at" => "2026-10-25T07:13:00" ) )
    expect { workflow.complete( event.uuid ) }.to raise_error( described_class::Invalid, /five minutes/ )
    workflow.update( event.uuid, effort_fields.merge( "method_followed" => "false" ) )
    expect { workflow.complete( event.uuid ) }.to raise_error( described_class::Invalid, /Explain/ )
  end

  it "requires both explicit assessments and weather before completion" do
    workflow.update( event.uuid, effort_fields.merge( "all_detections_reported" => "", "noise" => "" ) )
    expect { workflow.complete( event.uuid ) }.to raise_error( ActiveRecord::RecordInvalid )
    expect( event.reload.status ).to eq "in_progress"
  end

  it "saves incomplete reporting without treating it as absence" do
    workflow.update( event.uuid, effort_fields.merge( "all_detections_reported" => "false" ) )
    expect( workflow.complete( event.uuid ).completion_status ).to eq "incomplete"
  end

  it "records heard-only unidentified birds and rejects duplicate totals or fractional counts" do
    workflow.add_detection( event.uuid, detection_fields )
    expect( event.survey_detections.first.taxon ).to eq Surveys::PointCountProtocol.birds
    expect do
      workflow.add_detection( event.uuid, detection_fields )
    end.to raise_error( described_class::Invalid, /already/ )
    expect do
      workflow.add_detection( event.uuid,
        detection_fields.merge( "quantity" => "1.5" ) )
    end.to raise_error( described_class::Invalid )
  end

  it "limits taxonomy to birds, including descendants" do
    root = Surveys::PointCountProtocol.birds
    bird = Taxon.insert_all!( [{ name: "PointCountBird", rank: "species", rank_level: 10,
                                 ancestry: [root.ancestry, root.id].compact.join( "/" ), is_active: true,
                                 created_at: Time.current, updated_at: Time.current }] ).rows.first.first
    workflow.add_detection( event.uuid, detection_fields.merge( "taxon_id" => bird ) )
    nonbird = Taxon.insert_all!( [{ name: "PointCountPlant", rank: "species", rank_level: 10,
                                    is_active: true, created_at: Time.current,
                                    updated_at: Time.current }] ).rows.first.first
    expect do
      workflow.add_detection( event.uuid,
        detection_fields.merge( "taxon_id" => nonbird ) )
    end.to raise_error( ActiveRecord::RecordNotFound )
  end

  it "rolls back a detection if linked evidence belongs to someone else" do
    observation = Observation.insert_all!( [{ user_id: another_user.id, created_at: Time.current,
                                              updated_at: Time.current }] ).rows.first.first
    event
    expect do
      expect do
        workflow.add_detection( event.uuid,
          detection_fields.merge( "observation_id" => observation ) )
      end.to raise_error( ActiveRecord::RecordNotFound )
    end.not_to change( SurveyDetection, :count )
  end

  it "removes a draft detection and its link without deleting the observation" do
    observation = Observation.insert_all!( [{ user_id: survey_user.id, created_at: Time.current,
                                              updated_at: Time.current }] ).rows.first.first
    workflow.add_detection( event.uuid, detection_fields.merge( "observation_id" => observation ) )
    workflow.remove_detection( event.uuid, event.survey_detections.first.uuid )
    expect( event.survey_detections.reload ).to be_empty
    expect( Observation.exists?( observation ) ).to be true
  end

  it "does not grant another user access to events, stations, or mutations" do
    stranger = described_class.new( another_user )
    expect( stranger.events ).not_to include event
    expect do
      stranger.create( "station_uuid" => event.survey_sampling_unit.uuid )
    end.to raise_error( ActiveRecord::RecordNotFound )
    expect { stranger.update( event.uuid, effort_fields ) }.to raise_error( ActiveRecord::RecordNotFound )
    expect { stranger.add_detection( event.uuid, detection_fields ) }.to raise_error( ActiveRecord::RecordNotFound )
    expect { stranger.complete( event.uuid ) }.to raise_error( ActiveRecord::RecordNotFound )
  end

  it "allows timing corrections atomically without violating existing effort bounds" do
    workflow.update( event.uuid, effort_fields )
    workflow.update( event.uuid,
      effort_fields.merge( "started_at" => "2026-10-25T08:10:00", "ended_at" => "2026-10-25T08:15:00" ) )
    expect( event.reload.started_at.hour ).to eq 12
    expect do
      workflow.update( event.uuid,
        effort_fields.merge( "wind" => "hurricane" ) )
    end.to raise_error( ActiveRecord::RecordInvalid )
    expect( event.reload.started_at.hour ).to eq 12
  end

  it "freezes completed visits, preserves void history, and rejects invalid coordinates" do
    workflow.update( event.uuid, effort_fields )
    workflow.complete( event.uuid )
    expect { workflow.add_detection( event.uuid, detection_fields ) }.to raise_error( described_class::Invalid )
    expect { workflow.update( event.uuid, effort_fields ) }.to raise_error( described_class::Invalid )
    workflow.void( event.uuid, "Wrong station; replacement needed" )
    expect( event.reload.status ).to eq "void"
    expect( event.completed_at ).not_to be_nil
    expect do
      workflow.create( station_fields.merge( "station_latitude" => "NaN" ) )
    end.to raise_error( described_class::Invalid )
  end
end

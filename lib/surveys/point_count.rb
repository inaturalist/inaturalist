# frozen_string_literal: true

module Surveys
  # Browser-facing operations. Generic survey services remain privileged internals.
  class PointCount
    class Invalid < StandardError; end

    def initialize( user )
      raise ActiveRecord::RecordNotFound unless user

      @user = user
    end

    def events
      SurveyEvent.joins( survey_protocol_version: :survey_protocol ).where( user_id: @user.id,
        survey_protocols: { uuid: PointCountProtocol::UUID }, survey_protocol_versions: { version_number: 1 } )
    end

    def stations
      SurveySamplingUnit.joins( :survey_site ).where(
        survey_sites: { created_by_user_id: @user.id, location_privacy: "private" },
        unit_type: "point", status: "active"
      )
    end

    def create( data )
      SurveyEvent.transaction( requires_new: true ) do
        v = PointCountProtocol.version
        raise Invalid, "This protocol is not available for new visits." unless v.status == "published"

        station = if data["station_uuid"].present?
          stations.find_by!( uuid: data["station_uuid"] )
        else
          create_station( data )
        end
        event = CreateSurveyEvent.call( protocol_version: v, user: @user, survey_sampling_unit: station,
          location_privacy: "private", status: "in_progress" )
        event.survey_event_participants.create!( user: @user, role: "observer" )
        event.survey_efforts.create!( method: "point_count", observer_count: 1 )
        measurement( event, "radius_meters", 50 )
        event
      end
    end

    def update( uuid, data )
      mutate( uuid ) do | event |
        zone = ActiveSupport::TimeZone[data["time_zone"]]
        raise Invalid, "Choose a valid time zone." unless zone

        start = parse_time( zone, data["started_at"] )
        finish = parse_time( zone, data["ended_at"] )
        raise Invalid, "End time must be after start time." if finish && ( start.nil? || finish <= start )

        # Widen the event temporarily, so both old and new effort remain inside it.
        # All intermediate state is transactional and locked.
        effort = event.survey_efforts.first!
        event.update!( started_at: [event.started_at, start].compact.min, ended_at: nil )
        effort.update!( started_at: nil, ended_at: nil )
        event.update!( started_at: start, ended_at: finish, time_zone: zone.name, remarks: data["remarks"] )
        effort.update!( started_at: start, ended_at: finish, duration_seconds: finish && ( finish - start ).to_i )
        %w(method_followed all_detections_reported).each do | key |
          measurement( event, key, boolean( data[key] ) )
        end
        %w(precipitation wind noise deviation_reason).each do | key |
          measurement( event, key, data[key].presence )
        end
        complete = boolean( data["all_detections_reported"] )
        coverage = { nil => "unknown", true => "complete", false => "incomplete" }.fetch( complete )
        event.update!( completion_status: coverage )
        event.survey_event_targets.first!.update!( status: "surveyed", coverage_complete: complete,
          absence_reporting: false )
      end
    end

    def add_detection( uuid, data )
      mutate( uuid ) do | event |
        taxon = PointCountProtocol.bird_taxa.find( data["taxon_id"] )
        unless data["quantity"].to_s.match?( /\A[1-9]\d{0,6}\z/ )
          raise Invalid,
            "Count must be a positive whole number."
        end
        raise Invalid, "Choose seen, heard, or both." unless %w(seen heard both).include?( data["detection_method"] )
        if event.survey_detections.exists?( taxon_id: taxon.id )
          raise Invalid, "This taxon already has a count. Remove that row and enter its corrected total."
        end

        detection = event.survey_detections.create!( taxon: taxon, quantity: data["quantity"],
          quantity_type: "individuals", occurrence_status: "present", recorded_by_user: @user,
          survey_event_target: event.survey_event_targets.first!, survey_effort: event.survey_efforts.first!,
          remarks: data["remarks"] )
        measurement( event, "detection_method", data["detection_method"], detection: detection )
        if data["observation_id"].present?
          observation = Observation.where( user_id: @user.id ).find( data["observation_id"] )
          event.survey_observations.create!( observation: observation, survey_detection: detection )
        end
      end
    end

    def remove_detection( uuid, detection_uuid )
      mutate( uuid ) do | event |
        detection = event.survey_detections.find_by!( uuid: detection_uuid )
        detection.survey_observations.destroy_all
        detection.survey_measurements.destroy_all
        detection.destroy!
      end
    end

    def complete( uuid )
      mutate( uuid ) do | event |
        effort = event.survey_efforts.first!
        raise Invalid, "Record start and end times with positive effort." unless effort.duration_seconds.to_i.positive?

        values = self.class.values( event )
        followed = values["method_followed"]
        nonconforming = effort.duration_seconds != 300 ||
          values["precipitation"] != "none" || values["wind"] == "strong"
        if followed && nonconforming
          raise Invalid,
            "Method compliance requires exactly five minutes, no precipitation, and no strong wind. " \
              "Otherwise select No and explain the deviation."
        end
        if followed == false && values["deviation_reason"].blank?
          raise Invalid, "Explain the interruption or protocol deviation."
        end

        CompleteSurveyEvent.call( event )
      end
    end

    def void( uuid, reason )
      event = events.find_by!( uuid: uuid )
      event.with_lock do
        raise Invalid, "Only a completed visit can be voided here." unless event.status == "completed"
        raise Invalid, "A correction reason is required." if reason.blank?

        event.void!( reason: reason )
      end
      event
    end

    def self.values( event )
      event.survey_measurements.where( survey_detection_id: nil ).
        includes( :survey_measurement_definition ).to_h do | m |
        [m.survey_measurement_definition.field_key,
         m.value_boolean.nil? ? ( m.value_text || m.value_numeric ) : m.value_boolean]
      end
    end

    private

    def mutate( uuid )
      event = events.find_by!( uuid: uuid )
      SurveyEvent.transaction( requires_new: true ) do
        event.lock!
        raise Invalid, "Completed and void visits cannot be edited." unless
          %w(planned in_progress).include?( event.status )

        yield event
      end
      event.reload
    end

    def create_station( data )
      lat = Float( data["station_latitude"], exception: false )
      lng = Float( data["station_longitude"], exception: false )
      unless lat && lng && lat.finite? && lng.finite? && lat.between?( -90, 90 ) && lng.between?( -180, 180 )
        raise Invalid, "Enter valid station latitude and longitude."
      end
      raise Invalid, "Give the station a name." if data["station_name"].blank?

      site = SurveySite.create!( name: data["station_name"], created_by_user: @user, location_privacy: "private" )
      site.survey_sampling_units.create!( code: "point-1", name: data["station_name"], unit_type: "point",
        geom: "POINT(#{lng} #{lat})" )
    end

    def boolean( value )
      return true if value == "true"
      return false if value == "false"
      return nil if value.blank?

      raise Invalid, "Choose Yes or No."
    end

    def parse_time( zone, text )
      return nil if text.blank?

      unless text.match?( /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?\z/ )
        raise Invalid,
          "Enter a valid local date and time."
      end

      zone.strptime( text, ( text.length == 16 ) ? "%Y-%m-%dT%H:%M" : "%Y-%m-%dT%H:%M:%S" )
    rescue ArgumentError
      raise Invalid, "Enter a valid local date and time."
    end

    def measurement( event, key, value, detection: nil )
      definition = event.survey_protocol_version.survey_measurement_definitions.find_by!( field_key: key )
      scope = event.survey_measurements.where( survey_measurement_definition: definition, survey_detection: detection )
      if value.nil?
        scope.first&.destroy!
        return
      end
      m = scope.first_or_initialize
      column = { "numeric" => :value_numeric, "boolean" => :value_boolean }.fetch( definition.data_type, :value_text )
      m.assign_attributes( value_numeric: nil, value_text: nil, value_boolean: nil, unit: definition.unit )
      m[column] = value
      m.save!
    end
  end
end

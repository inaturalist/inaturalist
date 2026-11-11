# frozen_string_literal: true

module Surveys
  # An explicit, immutable pilot definition, installed by an operator, not a GET request.
  class PointCountProtocol
    UUID = "b7c279b1-683e-4c2a-9319-5b10c4b82c4b"
    TITLE = "Stationary Bird Point Count — 5 minutes, 50-metre radius"
    INSTRUCTIONS = <<~TEXT
      Count all wild birds seen or heard within 50 metres of a fixed station for five uninterrupted minutes.
      One active observer; a companion may take notes but must not contribute detections.
      Arrive quietly and wait one minute before starting. Remain at the station. Binoculars are allowed;
      playback, pishing, baiting and approaching birds are excluded. Prefer the first three hours after sunrise;
      avoid rain and strong wind. Record actual times, weather and disruptive noise.
      Count each individual once. Include birds using the habitat, including aerial foraging; exclude mere flyovers.
      Exclude birds outside the radius or of uncertain distance from counts; put them in notes instead.
      Use the minimum number confidently distinguished and note uncertainty. Unidentified birds are valid:
      choose a broader iNaturalist taxon, including Aves. Record seen, heard, or both for each count.
      Confirm method compliance separately from whether every in-scope detection was reported.
      Keep interrupted or nonconforming visits with actual effort and a deviation reason. No detections is valid;
      never manufacture species absence records. These are detection counts, not a population census.
    TEXT
    EVENT_FIELDS = {
      "radius_meters" => { label: "Sampling radius", data_type: "numeric", unit: "m",
                           validation_rules: { min: 50, max: 50 } },
      "method_followed" => { label: "Prescribed method followed for five uninterrupted minutes", data_type: "boolean" },
      "all_detections_reported" => { label: "Every in-scope detection reported", data_type: "boolean" },
      "deviation_reason" => { label: "Deviation reason", data_type: "text", required: false },
      "precipitation" => { label: "Precipitation", data_type: "categorical", allowed_values: %w(none rain snow) },
      "wind" => { label: "Wind", data_type: "categorical", allowed_values: %w(calm light moderate strong) },
      "noise" => { label: "Disruptive noise", data_type: "categorical",
                   allowed_values: %w(none intermittent continuous) }
    }.freeze

    def self.version
      SurveyProtocol.find_by!( uuid: UUID ).survey_protocol_versions.find_by!( version_number: 1 )
    end

    def self.birds
      Taxon.find_by!( name: "Aves", rank: "class", is_active: true )
    end

    def self.bird_taxa
      root = birds
      path = [root.ancestry, root.id].compact.join( "/" )
      Taxon.where( id: root.id ).or( Taxon.where( "ancestry = ? OR ancestry LIKE ?",
        path, "#{path}/%" ) )
    end

    def self.install!( owner: )
      SurveyProtocol.transaction do
        # Serialize retries without modifying any existing user or published definition.
        SurveyProtocol.connection.execute( "SELECT pg_advisory_xact_lock(74251, 1)" )
        return version if SurveyProtocol.exists?( uuid: UUID )

        protocol = SurveyProtocol.create!( uuid: UUID, user: owner, title: TITLE,
          status: "active", description: "Private pilot for repeatable stationary bird counts." )
        v = protocol.survey_protocol_versions.create!( version_number: 1, instructions: INSTRUCTIONS,
          definition: { allowed_methods: ["point_count"], require_effort: true,
                        required_effort_fields: %w(duration_seconds observer_count) } )
        v.survey_targets.create!( label: "All wild birds within 50 metres", scope_type: "taxon_group",
          taxon: birds, required: true, position: 0,
          scope_definition: {
            description: "Wild birds using habitat within a 50-metre horizontal radius; " \
              "excludes mere flyovers and uncertain distances."
          } )
        EVENT_FIELDS.each do | key, definition |
          v.survey_measurement_definitions.create!( { field_key: key, applies_to: "event",
                                                      required: true }.merge( definition ) )
        end
        v.survey_measurement_definitions.create!( field_key: "detection_method", label: "Detected by",
          applies_to: "detection", required: true, data_type: "categorical", allowed_values: %w(seen heard both) )
        PublishSurveyProtocolVersion.call( v )
      end
    end
  end
end

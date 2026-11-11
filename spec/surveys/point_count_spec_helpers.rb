# frozen_string_literal: true

module PointCountSpecHelpers
  def prepare_point_count
    unless Taxon.exists?( name: "Aves", rank: "class", is_active: true )
      Taxon.insert_all!( [{ name: "Aves", rank: "class", rank_level: 50, is_active: true,
                            created_at: Time.current, updated_at: Time.current }] )
    end
    Surveys::PointCountProtocol.install!( owner: survey_user )
  end

  def station_fields
    { "station_name" => "Pond North", "station_latitude" => "42.4", "station_longitude" => "-71.1" }
  end

  def effort_fields
    { "started_at" => "2026-10-25T07:10:00", "ended_at" => "2026-10-25T07:15:00",
      "time_zone" => "Eastern Time (US & Canada)", "method_followed" => "true",
      "all_detections_reported" => "true", "precipitation" => "none", "wind" => "light", "noise" => "none" }
  end

  def detection_fields
    { "taxon_id" => Surveys::PointCountProtocol.birds.id.to_s, "quantity" => "2", "detection_method" => "heard" }
  end

  def another_user
    User.find( User.insert_all!( [{ login: "other_#{SecureRandom.hex( 5 )}",
                                    email: "#{SecureRandom.hex( 5 )}@example.org",
                                    created_at: Time.current, updated_at: Time.current }] ).rows.first.first )
  end
end

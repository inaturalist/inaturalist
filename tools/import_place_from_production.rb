# frozen_string_literal: true

if Rails.env.production?
  puts "This script is for setting up a dev environment only."
  exit 0
end

module ImportPlaceFromProduction
  API = Faraday.new( "https://api.inaturalist.org" ) do | faraday |
    faraday.response :raise_error
  end

  def self.fetch_place( id_or_slug )
    http_response = API.get( "/v1/places/#{id_or_slug.to_s.parameterize}" )
    response = JSON.parse( http_response.body )

    unless response["results"].one?
      raise "Expected exactly one result from API, got #{response['total_results']}"
    end

    response["results"].first
  end

  def self.import_from_result( result, parent: )
    existing = Place.where( uuid: result["uuid"] ).first
    return existing if existing

    Place.transaction do
      Rails.logger.info "Importing place #{result['name']}"

      latitude, longitude = result["location"].split( "," )
      place = Place.new(
        admin_level: result["admin_level"],
        display_name: result["display_name"],
        latitude: latitude,
        longitude: longitude,
        name: result["name"],
        parent: parent,
        place_type: result["place_type"],
        slug: result["slug"],
        uuid: result["uuid"]
      )

      geom = RGeo::GeoJSON.decode( result["geometry_geojson"] )
      if geom && geom.geometry_type != RGeo::Feature::MultiPolygon
        geom = RGeo::Geos.factory.multi_polygon( [geom] )
      end
      # saves the place as well. Swallows validation errors but adds them to #errors
      place.save_geom( geom )

      unless place.place_geometry.persisted?
        raise "Failed to save geometry: #{place.place_geometry.errors.full_messages.to_sentence}"
      end

      place.save!

      place
    end
  end

  # Import the place via the production iNaturalist API, ensuring its ancestors also exist
  # API docs: https://api.inaturalist.org/v1/docs/#!/Places/get_places_id
  def self.import_place( id_or_slug )
    # contents have null for ancestor_place_ids
    # if ancestor_place_ids is not null, the place is its own last ancestor
    ids_to_import = fetch_place( id_or_slug )["ancestor_place_ids"] || [id_or_slug]
    ids_to_import.
      map( &method( :fetch_place ) ).
      inject( nil ) {| parent, place | import_from_result( place, parent: parent ) }
  end
end

place = ImportPlaceFromProduction.import_place( ARGV[0] )
puts Rails.application.routes.url_helpers.place_url( place, host: "localhost", port: 3000 )

# frozen_string_literal: true

unless Rails.env.development?
  puts "Importing data is only supported in the development environment"
  exit 1
end

require_relative "taxon_importer/taxon_importer"
require "optimist"
require "open-uri"
require "faker"

OPTS = Optimist.options do
  banner <<~BANNER
    Import observations from production iNaturalist. Useful for testing or seeding.

    Usage:

      rails r tools/development_tools/import_observation_from_production.rb --ids=137914892,142389012,124056026,175598147,36834943,1932333,55899839,36703818

    Options:
  BANNER
  opt :ids, "Comma-separated list of observation IDs to import", type: :string, short: "-i"
  opt :photo_quality, "Square, medium, large, original. Default: medium", type: :string, short: "-q"
end

module ImportObservationFromProduction
  # this simply prints the url being fetched
  class RequestPrinter < Faraday::Middleware
    def call( env )
      puts env[:url]
      @app.call( env )
    end
  end

  API = Faraday.new( "https://api.inaturalist.org" ) do | faraday |
    faraday.use RequestPrinter
    faraday.response :raise_error
  end

  # TODO: support projects
  # TODO: support annotations
  # TODO: support observation fields
  # TODO: add relevant places
  #
  # @param ids [string] Comma-separated list of observation IDs to import
  # @param opts [Hash] Options
  # @option opts [string] :photo_quality Import observations to a project
  def self.import_observations( ids, opts = {} )
    raise "You must specify observation ID(s)" if ids.blank?

    opts[:photo_quality] ||= "medium"

    user_id = get_user_ids( ids )
    observations = API.get( "/v2/observations?id=#{ids}&user_id=#{user_id}&fields=all" )
    json = JSON.parse( observations.body, symbolize_names: true )

    json[:results].each do | obs_data |
      puts "Importing https://www.inaturalist.org/observations/#{obs_data[:id]}"

      # 1. Import dependencies (taxa, users)
      import_taxa( obs_data )
      import_users( obs_data )

      # 2. Make the observation
      is_newly_created, observation = make_observation( obs_data )

      # 3. Decorate with photos, identifications, etc.
      add_photos( obs_data, observation, opts[:photo_quality] ) if is_newly_created
      add_identifications( obs_data, observation ) if is_newly_created
    end
  end

  #======================================#
  ## Private Methods                    ##
  ###==================================###

  def self.get_user_ids( observation_ids )
    resp = API.get( "/v2/observations?id=#{observation_ids}&fields=id,user.id" )
    json = JSON.parse( resp.body, symbolize_names: true )

    user_ids = json[:results].map {| r | r.dig( :user, :id ) }
    user_ids.join( "," )
  end

  def self.import_taxa( obs_data )
    taxon_ids = [
      obs_data.dig( :taxon, :id ),
      obs_data[:identifications].map {| i | i[:taxon_id] }
    ].flatten.compact.uniq
    puts "Importing #{taxon_ids.size} taxons..."
    taxon_ids.map {| taxon_id | TaxonImporter.import( taxon_id: ) }
  end

  def self.import_users( obs_data )
    relevant_users = [
      obs_data[:user],
      obs_data[:annotations].map {| a | a[:user] },
      obs_data[:faves].map {| f | f[:user] },
      obs_data[:identifications].map {| i | i[:user] }
    ].flatten.compact.uniq {| u | u[:id] }
    puts "Importing #{relevant_users.size} users..."
    relevant_users.each do | user |
      User.find_or_create_by!( login: user[:login] ) do | u |
        u.login = user[:login]
        u.email = "#{user[:login]}@example.com"
        u.password = Faker::Internet.password
        u.created_at = user[:created_at]
      end
    end
  end

  def self.make_observation( obs_data )
    observer = User.find_by( login: obs_data.dig( :user, :login ) )
    longitude, latitude = obs_data.dig( :geojson, :coordinates )

    observation = Observation.find_or_initialize_by( uuid: obs_data[:uuid] ) do | obs |
      obs.created_at = obs_data[:created_at]
      obs.latitude = latitude
      obs.longitude = longitude
      obs.user = observer
      obs.description = obs_data[:description]
      obs.observed_on_string = obs_data[:observed_on]
      obs.taxon = Taxon.find_by( name: obs_data[:taxon][:name], rank: obs_data[:taxon][:rank] )
    end
    is_newly_created = observation.new_record?
    observation.save!

    [is_newly_created, observation]
  end

  def self.add_photos( obs_data, observation, photo_quality )
    puts "Downloading #{obs_data[:photos].size} photos..."
    observer = User.find_by( login: obs_data.dig( :user, :login ) )
    obs_data[:photos].each do | photo |
      url = photo[:url].sub( "square", photo_quality )

      begin
        downloaded_io = URI.open( url )
        photo = LocalPhoto.new( user: observer )
        photo.file = downloaded_io
        photo.save!

        ObservationPhoto.create!( observation:, photo: )
      rescue StandardError => e
        next puts "Failed to download #{url}: #{e}"
      end
    end
  end

  def self.add_identifications( obs_data, observation )
    puts "Adding #{obs_data[:identifications].size} identifications..."
    obs_data[:identifications].each do | idn_data |
      ident = Identification.find_or_initialize_by(
        body: idn_data[:body],
        created_at: idn_data[:created_at],
        observation:,
        taxon: Taxon.find_by( name: idn_data[:taxon][:name], rank: idn_data[:taxon][:rank] ),
        user: User.find_by( login: idn_data[:user][:login] )
      )
      ident.assign_attributes( idn_data.slice( :body, :current, :category, :created_at ) )
      ident.save!
    end
  end

  private_class_method :get_user_ids, :import_taxa, :import_users, :make_observation, :add_photos, :add_identifications
end

ImportObservationFromProduction.import_observations( OPTS.ids )

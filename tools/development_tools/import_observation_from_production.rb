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

    json[:results].each do | observation |
      puts "Observation::#{observation[:id]}"

      # 1. create any taxons that don't exist
      taxon_ids = [
        observation.dig( :taxon, :id ),
        observation[:identifications].map {| i | i[:taxon_id] }
      ].flatten.compact.uniq
      puts "Importing #{taxon_ids.size} taxons..."
      local_taxon_ids = taxon_ids.map {| taxon_id | TaxonImporter.import( taxon_id: ) }

      # 2. create all relevant users
      relevant_users = [
        observation[:user],
        observation[:annotations].map {| a | a[:user] },
        observation[:faves].map {| f | f[:user] },
        observation[:identifications].map {| i | i[:user] }
      ].flatten.compact.uniq {| u | u[:id] }
      puts "Importing #{relevant_users.size} users..."
      relevant_users.each {| user | find_or_create_user!( user ) }

      observer = find_or_create_user!( observation[:user] )

      # 3. make the observation
      longitude, latitude = observation.dig( :geojson, :coordinates )
      o = Observation.find_or_create_by( {
        latitude:,
        longitude:,
        created_at: observation[:created_at]
      } ) do | obs |
        obs.user = observer
        obs.taxon = Taxon.find_by_id( local_taxon_ids.first )
        obs.observed_on_string = observation[:observed_on]
        obs.description = observation[:description]
      end
      o.save!

      # 4. add photos
      observation[:photos].each do | photo |
        url = photo[:url].sub( "square", opts[:photo_quality] )

        begin
          downloaded_io = URI.open( url )
          photo = LocalPhoto.new( user: observer )
          photo.file = downloaded_io
          photo.save!

          ObservationPhoto.create!( observation: o, photo: )
        rescue StandardError => e
          next puts "Failed to download #{url}: #{e}"
        end
      end

      # 5. add identifications
      observation[:identifications].each do | idn_attrs |
        ident = Identification.find_or_initialize_by(
          body: idn_attrs[:body],
          created_at: idn_attrs[:created_at],
          observation: o,
          taxon: Taxon.find_by( name: idn_attrs[:taxon][:name], rank: idn_attrs[:taxon][:rank] ),
          user: User.find_by( login: idn_attrs[:user][:login] )
        )
        ident.assign_attributes(
          idn_attrs.slice( :body, :current, :category, :uuid, :created_at )
        )
        ident.save!
      end
    end
  end

  def self.get_user_ids( observation_ids )
    resp = API.get( "/v2/observations?id=#{observation_ids}&fields=id,user.id" )
    json = JSON.parse( resp.body, symbolize_names: true )

    user_ids = json[:results].map {| r | r.dig( :user, :id ) }
    user_ids.join( "," )
  end

  def self.find_or_create_user!( user )
    User.find_or_create_by!( login: user[:login] ) do | u |
      u.login = user[:login]
      u.email = "#{user[:login]}@example.com"
      u.password = Faker::Internet.password
      u.created_at = user[:created_at]
    end
  end

  private_class_method :get_user_ids, :find_or_create_user!
end

ImportObservationFromProduction.import_observations( OPTS.ids )

require "rubygems"
require "optimist"

OPTS = Optimist::options do
    banner <<-EOS

Exports select data for a particular site within this installation to CSV files
in a ZIP archive, including observations, users, and anything else network
partners are contractually entitled to. This data is *not* intended to recreate
a full instance of this application. That's what export_site_archive.rb is for.

Relevant observations are assumed to be
  * all records explicitly associated with the site
  * all records in the site's place

Private coordinates will be included for
  * all records explicitly associated with the site
  * all records in the site's place obscured by taxon geoprivacy  

Usage:

  rails runner tools/export_site_data.rb SITE_NAME

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
  opt :file, "Where to write the zip archive. Default will be tmp path.", :type => :string, :short => "-f"
  opt :site_name, "Site name", type: :string, short: "-s"
  opt :site_id, "Site ID", type: :string, short: "-i"
end

OBS_COLUMNS = %w(
  id
  observed_on_string
  observed_on
  time_observed_at
  time_zone
  out_of_range
  user_id
  user_login
  created_at
  updated_at
  quality_grade
  license
  url
  image_url
  sound_url
  tag_list
  description
  id_please
  num_identification_agreements
  num_identification_disagreements
  captive_cultivated
  oauth_application_id
  place_guess
  latitude
  longitude
  positional_accuracy
  private_place_guess
  private_latitude
  private_longitude
  private_positional_accuracy
  geoprivacy
  taxon_geoprivacy
  coordinates_obscured
  positioning_method
  positioning_device
  place_town_name
  place_county_name
  place_state_name
  place_country_name
  place_admin1_name
  place_admin2_name
  species_guess
  scientific_name
  common_name
  iconic_taxon_name
  taxon_id
)

def system_call(cmd)
  puts "Running #{cmd}" if OPTS[:debug]
  system cmd
end

start_time = Time.now
@site_name = OPTS.site_name || ARGV[0]
@site = Site.find_by_name(@site_name)
@site ||= Site.find_by_id(OPTS.site_id)
unless @site
  Optimist::die "No site with name '#{@site_name}'"
end
@site_name = @site.name
@dbname = ActiveRecord::Base.configurations[Rails.env]["database"]
@dbhost = ActiveRecord::Base.configurations[Rails.env]["host"]

# Make a temp dir
@work_dir = Dir.mktmpdir
@basename = "#{@site_name.parameterize}-#{Date.today.to_s.gsub(/\-/, '')}-#{Time.now.to_i}"
@work_path = File.join( @work_dir, @basename )
FileUtils.mkdir_p @work_path, :mode => 0755

# Export users table
path = File.join( @work_path, "#{@basename}-users.csv" )
sql = <<-SQL
  SELECT
    id,
    created_at,
    updated_at,
    login,
    name,
    email,
    time_zone,
    description,
    observations_count,
    identifications_count,
    suspended_at,
    uri,
    locale,
    place_id,
    last_active
  FROM
    users
  WHERE
    site_id = #{@site.id}
    AND spammer != 't'
SQL
cmd = "psql #{@dbname} -h #{@dbhost} -c \"COPY (#{sql.gsub( /\s+/m, " ")}) TO STDOUT WITH CSV HEADER\" > #{path}"
system_call cmd

def export_observations( options = {} )
  puts "Exporting observations, options: #{options}" if OPTS[:debug]
  filters = [
    { term: { spam: false } }
  ]
  inverse_filters = []
  if options[:site_id]
    filters << { term: { site_id: options[:site_id]} }
  end
  if options[:not_site_id]
    inverse_filters << { term: { site_id: options[:not_site_id]} }
  end
  if options[:place_id]
    filters << { terms: { "private_place_ids" => [ options[:place_id] ].flatten.map{ |v|
      ElasticModel.id_or_object(v)
    } } }
  end
  if options[:geoprivacy]
    if options[:geoprivacy].include?( "open" )
      inverse_filters << { exists: { field: "geoprivacy" } }
    else
      filters << { terms: { "geoprivacy" => [ options[:geoprivacy] ].flatten.map{ |v|
        ElasticModel.id_or_object(v)
      } } }
    end
  end
  if options[:not_geoprivacy]
    inverse_filters << { terms: { "geoprivacy" => [ options[:not_geoprivacy] ].flatten.map{ |v|
      ElasticModel.id_or_object(v)
    } } }
  end
  if options[:taxon_geoprivacy]
    filters << { terms: { "taxon_geoprivacy" => [ options[:taxon_geoprivacy] ].flatten.map{ |v|
      ElasticModel.id_or_object(v)
    } } }
  end
  if options[:not_taxon_geoprivacy]
    inverse_filters << { terms: { "taxon_geoprivacy" => [ options[:not_taxon_geoprivacy] ].flatten.map{ |v|
      ElasticModel.id_or_object(v)
    } } }
  end

  min_id = 0
  if options[:csv_path]
    csv_path = options[:csv_path]
    mode = "a"
  else
    csv_path = File.join( @work_path, "#{@basename}-observations.csv" )
    mode = "w"
  end
  obs_i = 0
  CSV.open( csv_path, mode ) do |csv|
    unless options[:csv_path]
      csv << OBS_COLUMNS
    end
    while true do
      filters << { range: { id: { gte: min_id } } }
      observations = Observation.elastic_paginate(
        filters: filters,
        inverse_filters: inverse_filters,
        sort: { id: "asc" },
        per_page: 1000
      )
      break if observations.size == 0
      Observation.preload_associations( observations, [
        :user,
        { identifications: [:stored_preferences] },
        { photos: :user },
        :sounds,
        :quality_metrics,
        { observations_places: :place }
      ] )
      observations.each do |o|
        if OPTS[:debug]
          msg = "Obs #{obs_i} (#{o.id})"
          msg += " [#{options[:debug_label]}]" if options[:debug_label]
          puts msg
        end
        o.localize_locale = @site.locale
        o.localize_place = @site.place
        csv << OBS_COLUMNS.map do |c|
          c = "cached_tag_list" if c == "tag_list"
          if c =~ /^private_/ && !options[:force_coordinate_visibility]
            nil
          else
            o.send(c) rescue nil
          end
        end
        obs_i += 1
        min_id = o.id + 1
      end
    end
  end
  csv_path
end

# Export observations by site users with private coordinates
obs_csv_path = export_observations(
  site_id: @site.id,
  force_coordinate_visibility: true,
  debug_label: "by site users"
)
# Export observations in place by non-site users *only* obscured by taxon geoprivacy with private coordinates
obs_csv_path = export_observations(
  not_site_id: @site.id,
  place_id: @site.place_id,
  taxon_geoprivacy: ["obscured", "private"],
  geoprivacy: ["open"],
  force_coordinate_visibility: true,
  csv_path: obs_csv_path,
  debug_label: "by non-site users w/ taxon_geoprivacy but not geoprivacy"
)
obs_csv_path = export_observations(
  not_site_id: @site.id,
  place_id: @site.place_id,
  taxon_geoprivacy: ["obscured", "private"],
  geoprivacy: ["obscured", "private"],
  csv_path: obs_csv_path,
  debug_label: "by non-site users of w/ taxon_geoprivacy AND geoprivacy"
)
# Export observations in place by non-site users *not* obscured by taxon geoprivacy *without* private coordinates
obs_csv_path = export_observations(
  not_site_id: @site.id,
  place_id: @site.place_id,
  not_taxon_geoprivacy: ["obscured", "private"],
  csv_path: obs_csv_path,
  debug_label: "by non-site users of un-threatened taxa"
)

# Make the archive
fname = "#{@basename}.zip"
archive_path = File.join(@work_dir, fname)
system_call "cd #{@work_dir} && zip -D #{archive_path} #{@basename}/*"

if OPTS[:file]
  system_call("mv #{archive_path} #{OPTS[:file]}")
  archive_path = OPTS[:file]
end

puts "Exported #{archive_path} in #{Time.now - start_time} s"

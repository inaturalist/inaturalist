# frozen_string_literal: true

class SiteDataExporter
  OBS_COLUMNS = %w(
    id
    observed_on_string
    observed_on
    time_observed_at
    time_zone
    out_of_range
    user_id
    user_login
    site_id
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
    public_positional_accuracy
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
  ).freeze

  ASSOC_COLUMNS = {
    annotations: %w(
      id
      uuid
      resource_type
      resource_id
      created_at
      controlled_attribute_id
      controlled_attribute_label
      controlled_value_id
      controlled_value_label
      user_id
      vote_score
    ),
    comments: %w(
      id
      uuid
      parent_type
      parent_id
      created_at
      updated_at
      user_id
      body
    ),
    identifications: %w(
      id
      observation_id
      taxon_id
      user_id
      body
      created_at
      updated_at
      current
      taxon_change_id
      category
      uuid
      previous_observation_taxon_id
      disagreement
    ),
    quality_metrics: %w(
      id
      user_id
      observation_id
      metric
      agree
      created_at
      updated_at
    ),
    observation_field_values: %w(
      id
      observation_id
      observation_field_id
      value
      created_at
      updated_at
      user_id
      updater_id
      uuid
    ),
    observation_photos: %w(
      observation_id
      photo_id
      photo.uuid
      photo.user_id
      photo.medium_url
      photo.license_url
      photo.attribution_name
      photo.created_at
    ),
    observation_sounds: %w(
      observation_id
      sound_id
      sound.uuid
      sound.user_id
      sound.url
      sound.license_url
      sound.attribution_name
      sound.created_at
    )
  }.freeze

  ASSOC_REQUIRED_ATTRIBUTES = {
    observation_photos: "photo",
    observation_sounds: "sound"
  }.freeze

  def initialize( site, options = {} )
    @options = options
    @site = site
    @site_name = @site.name
    dbconfig = ActiveRecord::Base.configurations.configs_for( env_name: Rails.env ).first.configuration_hash
    @dbname = dbconfig[:database]
    @dbhost = dbconfig[:host]
    @psql_cmd = "psql #{@dbname} -h #{@dbhost}"
    if dbconfig[:username]
      @psql_cmd += " -U #{dbconfig[:username]}"
    end
    # If this is a development env, really make sure the password gets passed
    # in. In production this should work without a password
    if dbconfig[:password] && !Rails.env.production?
      @psql_cmd = "PGPASSWORD=#{dbconfig[:password]} #{@psql_cmd}"
    end
    @max_obs_id = options[:max_obs_id] || Observation.calculate( :maximum, :id ) || 0
    @num_processes = options[:num_processes].to_i.positive? ? options[:num_processes].to_i : 3
  end

  def self.basename_for_site( site )
    "#{site.name.parameterize}-#{site.id}"
  end

  def export
    # Make a temp dir
    @work_dir = Dir.mktmpdir
    @basename = SiteDataExporter.basename_for_site( @site )
    @work_path = File.join( @work_dir, @basename )
    FileUtils.mkdir_p @work_path, mode: 0o755

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
        AND (spammer = 'f' OR spammer IS NULL)
    SQL
    cmd = "#{@psql_cmd} -c \"COPY (#{sql.gsub( /\s+/m, ' ' )}) TO STDOUT WITH CSV HEADER\" > #{path}"
    system_call cmd

    # Export taxa table
    path = File.join( @work_path, "#{@basename}-taxa.csv" )
    sql = <<-SQL
      SELECT
        id,
        name,
        rank,
        created_at,
        updated_at,
        iconic_taxon_id,
        is_iconic,
        creator_id,
        updater_id,
        observations_count,
        rank_level,
        wikipedia_title,
        featured_at,
        ancestry,
        locked,
        is_active,
        taxon_framework_relationship_id,
        uuid
      FROM
        taxa
    SQL
    cmd = "#{@psql_cmd} -c \"COPY (#{sql.gsub( /\s+/m, ' ' )}) TO STDOUT WITH CSV HEADER\" > #{path}"
    system_call cmd

    # Export conservation_statuses table
    path = File.join( @work_path, "#{@basename}-conservation_statuses.csv" )
    sql = <<-SQL
      SELECT
        cs.id,
        cs.taxon_id,
        cs.user_id,
        cs.place_id,
        cs.source_id,
        cs.authority,
        cs.status,
        cs.url,
        cs.description,
        cs.geoprivacy,
        cs.iucn,
        cs.created_at,
        cs.updated_at,
        places.name AS place_name,
        places.display_name AS place_display_name
      FROM
        conservation_statuses cs
          LEFT JOIN places ON places.id = cs.place_id
    SQL
    cmd = "#{@psql_cmd} -c \"COPY (#{sql.gsub( /\s+/m, ' ' )}) TO STDOUT WITH CSV HEADER\" > #{path}"
    system_call cmd

    # Export observation_fields table
    path = File.join( @work_path, "#{@basename}-observation_fields.csv" )
    sql = <<-SQL
      SELECT
        id,
        name,
        datatype,
        user_id,
        description,
        created_at,
        updated_at,
        allowed_values,
        values_count,
        users_count,
        uuid
      FROM
        observation_fields
    SQL
    cmd = "#{@psql_cmd} -c \"COPY (#{sql.gsub( /\s+/m, ' ' )}) TO STDOUT WITH CSV HEADER\" > #{path}"
    system_call cmd

    # Export observations by site users with private coordinates
    export_observations(
      site_id: @site.id,
      force_coordinate_visibility: true,
      debug_label: "by site users"
    )
    # Export observations in place by non-site users *only* obscured by taxon geoprivacy with private coordinates
    export_observations(
      not_site_id: @site.id,
      place_id: ( [@site.place_id] + @site.places_sites.pluck( :place_id ) ).compact,
      taxon_geoprivacy: ["obscured", "private"],
      geoprivacy: ["open"],
      force_coordinate_visibility: true,
      debug_label: "by non-site users w/ taxon_geoprivacy but not geoprivacy"
    )
    export_observations(
      not_site_id: @site.id,
      place_id: ( [@site.place_id] + @site.places_sites.pluck( :place_id ) ).compact,
      taxon_geoprivacy: ["obscured", "private"],
      geoprivacy: ["obscured", "private"],
      debug_label: "by non-site users of w/ taxon_geoprivacy AND geoprivacy"
    )
    # Export observations in place by non-site users *not* obscured by taxon geoprivacy *without* private coordinates
    export_observations(
      not_site_id: @site.id,
      place_id: ( [@site.place_id] + @site.places_sites.pluck( :place_id ) ).compact,
      not_taxon_geoprivacy: ["obscured", "private"],
      debug_label: "by non-site users of un-threatened taxa"
    )

    # Make the archive
    fname = "#{@basename}.zip"
    archive_path = File.join( @work_dir, fname )
    system_call "cd #{@work_dir} && zip -#{!@options[:verbose] && 'q'}D #{archive_path} #{@basename}/*"
    archive_path
  end

  private

  def system_call( cmd )
    puts "Running #{cmd}" if @options[:debug]
    system cmd, exception: true
  end

  def export_observations( options = {} )
    filters = [
      { term: { spam: false } }
    ]
    inverse_filters = []
    if options[:site_id]
      filters << {
        bool: {
          should: [
            { term: { site_id: options[:site_id] } },
            { term: { "user.site_id" => options[:site_id] } }
          ]
        }
      }
    end
    if options[:not_site_id]
      inverse_filters << {
        bool: {
          should: [
            { term: { site_id: options[:not_site_id] } },
            { term: { "user.site_id" => options[:not_site_id] } }
          ]
        }
      }
    end
    if options[:place_id]
      filters << { terms: { "private_place_ids" => [options[:place_id]].flatten.map do | v |
        ElasticModel.id_or_object( v )
      end } }
    end
    if options[:geoprivacy]
      if options[:geoprivacy].include?( "open" )
        inverse_filters << { exists: { field: "geoprivacy" } }
      else
        filters << { terms: { "geoprivacy" => [options[:geoprivacy]].flatten.map do | v |
          ElasticModel.id_or_object( v )
        end } }
      end
    end
    if options[:not_geoprivacy]
      inverse_filters << { terms: { "geoprivacy" => [options[:not_geoprivacy]].flatten.map do | v |
        ElasticModel.id_or_object( v )
      end } }
    end
    if options[:taxon_geoprivacy]
      filters << { terms: { "taxon_geoprivacy" => [options[:taxon_geoprivacy]].flatten.map do | v |
        ElasticModel.id_or_object( v )
      end } }
    end
    if options[:not_taxon_geoprivacy]
      inverse_filters << { terms: { "taxon_geoprivacy" => [options[:not_taxon_geoprivacy]].flatten.map do | v |
        ElasticModel.id_or_object( v )
      end } }
    end
    if @options[:taxon_id]
      filters << {
        terms: { "taxon.ancestor_ids" => [ElasticModel.id_or_object( @options[:taxon_id] )] }
      }
    end

    base_es_params = {
      track_total_hits: true,
      filters: filters,
      inverse_filters: inverse_filters,
      sort: { id: "asc" },
      per_page: 1000
    }
    base_results = Observation.elastic_search( base_es_params.merge( per_page: 0 ) )
    total_entries = base_results.total_entries
    num_partitions = total_entries < 10_000 ? 1 : @num_processes
    partition_offset = @max_obs_id / num_partitions
    partitions = num_partitions.times.map do | i |
      ( i * partition_offset..( i + 1 ) * partition_offset )
    end

    if @options[:verbose]
      puts "[#{Time.now}] Exporting observations in #{num_partitions} partitions, options: #{options}"
    end

    csv_path = File.join( @work_path, "#{@basename}-observations.csv" )
    unless File.exist?( csv_path )
      CSV.open( csv_path, "w" ) do | csv |
        csv << OBS_COLUMNS
      end
    end
    puts "[#{Time.now}] Writing CSV to #{csv_path}" if @options[:verbose]

    # Set up CSV files for associate models
    assoc_csv_paths = {}
    ASSOC_COLUMNS.each do | k, columns |
      path = File.join( @work_path, "#{@basename}-#{k}.csv" )
      unless File.exist?( path )
        CSV.open( path, "w" ) do | csv |
          csv << columns
        end
      end
      assoc_csv_paths[k] = path
    end

    Parallel.each_with_index( partitions, in_processes: partitions.size ) do | partition, parition_i |
      partition_filters = filters.dup
      partition_filters << {
        range: { id: { gte: partition.min, lte: partition.max } }
      }
      partition_total_entries = Observation.elastic_search(
        base_es_params.merge( filters: partition_filters, per_page: 0 )
      ).total_entries
      if partition_total_entries <= 0
        puts "[#{Time.now}] Partition #{partition.min}-#{partition.max} is empty" if @options[:verbose]
        next
      end
      min_id = 0
      obs_i = 0
      loop do
        batch_filters = partition_filters.dup
        batch_filters << { range: { id: { gte: min_id } } }
        if @options[:debug]
          msg = ""
          msg += "[#{options[:debug_label]}]" if options[:debug_label]
          msg += " batch_filters: #{batch_filters}"
          puts msg
        end
        observations = try_and_try_again(
          [
            Patron::TimeoutError,
            Faraday::TimeoutError,
            Elasticsearch::Transport::Transport::Errors::TooManyRequests
          ]
        ) do
          Observation.elastic_paginate( base_es_params.merge( filters: batch_filters ) )
        end
        if observations.size.zero?
          puts "Observation batch #{partition.min}-#{partition.max} empty, moving on..." if @options[:verbose]
          break
        end
        if @options[:verbose]
          msg = "[#{Time.now}] "
          msg += "[#{options[:debug_label]}] " if options[:debug_label]
          msg += "Obs partition #{parition_i} (#{partition}) from #{min_id} (#{obs_i} / #{partition_total_entries}, "
          msg += "#{( obs_i.to_f / partition_total_entries * 100 ).round( 2 )}%)"
          print msg
          print "\r"
          $stdout.flush
        end
        Observation.preload_associations(
          observations,
          [
            :user,
            { taxon: { taxon_names: :place_taxon_names } },
            { identifications: [:stored_preferences] },
            { photos: [
              :flags, :file_prefix, :file_extension, :user, :moderator_actions
            ] },
            { sounds: [
              :flags, :moderator_actions, :user
            ] },
            :quality_metrics,
            { observations_places: :place },
            {
              annotations: [:votes_for, {
                controlled_attribute: [:labels],
                controlled_value: [:labels]
              }]
            },
            :observation_field_values,
            :comments
          ]
        )
        CSV.open( csv_path, "a" ) do | csv |
          observations.each do | o |
            if @options[:debug]
              msg = "Obs #{obs_i} (#{o.id})"
              msg += " [#{options[:debug_label]}]" if options[:debug_label]
              puts msg
            end
            o.localize_locale = @site.locale
            o.localize_place = @site.place
            csv << OBS_COLUMNS.map do | c |
              c = "cached_tag_list" if c == "tag_list"
              if c =~ /^private_/ && !options[:force_coordinate_visibility]
                nil
              else
                begin
                  o.send( c )
                rescue StandardError
                  nil
                end
              end
            end
            obs_i += 1
            min_id = o.id + 1
          end
        end
        ASSOC_COLUMNS.each do | association, cols |
          association = association.to_sym
          CSV.open( assoc_csv_paths[association], "a" ) do | csv |
            observations.each do | o |
              o.send( association ).each do | associate |
                # skip associates that lack a required attribute,
                # e.g. an observation_photo without a photo
                if ASSOC_REQUIRED_ATTRIBUTES[association] &&
                    !associate.send( ASSOC_REQUIRED_ATTRIBUTES[association] )
                  if @options[:debug]
                    msg = "Skipping #{association} #{associate} due to "
                    msg += "missing #{ASSOC_REQUIRED_ATTRIBUTES[association]}"
                    puts msg
                  end
                  next
                end
                # add the specified attributes of the associate as columns to its CSV file
                csv << cols.map do | col |
                  # allow dot-notation in column names, while still using the safer `send` method
                  col.split( "." ).inject( associate, :send ) rescue nil
                end
              end
            end
          end
        end
      end
    end
    csv_path
  end
end

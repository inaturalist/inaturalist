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
  )

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
    )
  }

  def initialize( site, options = {} )
    @site = site
    @site_name = @site.name
    @dbname = ActiveRecord::Base.configurations[Rails.env]["database"]
    @dbhost = ActiveRecord::Base.configurations[Rails.env]["host"]
    @max_obs_id = options[:max_obs_id] || Observation.calculate(:maximum, :id)
    @num_processes = options[:num_processes].to_i > 0 ? options[:num_processes].to_i : 3
    @options = options
  end

  def self.basename_for_site( site )
    "#{site.name.parameterize}-#{site.id}"
  end

  def export
    # Make a temp dir
    @work_dir = Dir.mktmpdir
    @basename = SiteDataExporter.basename_for_site( @site )
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
        AND (spammer = 'f' || spammer IS NULL)
    SQL
    cmd = "psql #{@dbname} -h #{@dbhost} -c \"COPY (#{sql.gsub( /\s+/m, " ")}) TO STDOUT WITH CSV HEADER\" > #{path}"
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
        unique_name,
        wikipedia_title,
        featured_at,
        ancestry,
        locked,
        is_active,
        complete_rank,
        complete,
        taxon_framework_relationship_id,
        uuid
      FROM
        taxa
    SQL
    cmd = "psql #{@dbname} -h #{@dbhost} -c \"COPY (#{sql.gsub( /\s+/m, " ")}) TO STDOUT WITH CSV HEADER\" > #{path}"
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
    cmd = "psql #{@dbname} -h #{@dbhost} -c \"COPY (#{sql.gsub( /\s+/m, " ")}) TO STDOUT WITH CSV HEADER\" > #{path}"
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
    cmd = "psql #{@dbname} -h #{@dbhost} -c \"COPY (#{sql.gsub( /\s+/m, " ")}) TO STDOUT WITH CSV HEADER\" > #{path}"
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
      place_id: [@site.place_id, @site.extra_place_id].compact,
      taxon_geoprivacy: ["obscured", "private"],
      geoprivacy: ["open"],
      force_coordinate_visibility: true,
      debug_label: "by non-site users w/ taxon_geoprivacy but not geoprivacy"
    )
    export_observations(
      not_site_id: @site.id,
      place_id: [@site.place_id, @site.extra_place_id].compact,
      taxon_geoprivacy: ["obscured", "private"],
      geoprivacy: ["obscured", "private"],
      debug_label: "by non-site users of w/ taxon_geoprivacy AND geoprivacy"
    )
    # Export observations in place by non-site users *not* obscured by taxon geoprivacy *without* private coordinates
    export_observations(
      not_site_id: @site.id,
      place_id: [@site.place_id, @site.extra_place_id].compact,
      not_taxon_geoprivacy: ["obscured", "private"],
      debug_label: "by non-site users of un-threatened taxa"
    )

    # Make the archive
    fname = "#{@basename}.zip"
    archive_path = File.join(@work_dir, fname)
    system_call "cd #{@work_dir} && zip -D #{archive_path} #{@basename}/*"  
    archive_path
  end

  private
  def system_call(cmd)
    puts "Running #{cmd}" if @options[:debug]
    system cmd
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
            { term: { site_id: options[:site_id]} },
            { term: { "user.site_id" => options[:site_id] } }
          ]
        }
      }
    end
    if options[:not_site_id]
      inverse_filters << {
        bool: {
          should: [
            { term: { site_id: options[:not_site_id]} },
            { term: { "user.site_id" => options[:not_site_id] } }
          ]
        }
      }
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
    num_partitions = total_entries < 10000 ? 1 : @num_processes
    partition_offset = @max_obs_id / num_partitions
    partitions = num_partitions.times.map do |i|
      (i*partition_offset..(i+1)*partition_offset)
    end

    puts "[#{Time.now}] Exporting observations in #{num_partitions} partitions, options: #{options}" if @options[:verbose]

    csv_path = File.join( @work_path, "#{@basename}-observations.csv" )
    unless File.exists?( csv_path )
      CSV.open( csv_path, "w" ) do |csv|
        csv << OBS_COLUMNS
      end
    end
    puts "[#{Time.now}] Writing CSV to #{csv_path}" if @options[:verbose]

    # Set up CSV files for associate models
    assoc_csv_paths = {}
    ASSOC_COLUMNS.each do |k, columns|
      path = File.join( @work_path, "#{@basename}-#{k}.csv" )
      unless File.exists?( path )
        CSV.open( path, "w" ) do |csv|
          csv << columns
        end
      end
      assoc_csv_paths[k] = path
    end

    Parallel.each_with_index( partitions, in_processes: partitions.size ) do |partition, parition_i|
      partition_filters = filters.dup
      partition_filters << {
        range: { id: { gte: partition.min, lte: partition.max } }
      }
      min_id = 0
      obs_i = 0
      while true do
        batch_filters = partition_filters.dup
        batch_filters << { range: { id: { gte: min_id } } }
        if @options[:debug]
          msg = ""
          msg += "[#{options[:debug_label]}]" if options[:debug_label]
          msg += " batch_filters: #{batch_filters}"
          puts msg
        end
        observations = try_and_try_again( [Patron::TimeoutError, Faraday::TimeoutError] ) do
          Observation.elastic_paginate(
            track_total_hits: true,
            filters: batch_filters,
            inverse_filters: inverse_filters,
            sort: { id: "asc" },
            per_page: 1000
          )
        end
        if observations.size == 0
          puts if @options[:verbose]
          break
        end
        if obs_i == 0
          partition_total_entries = observations.total_entries
        end
        if @options[:verbose]
          msg = "[#{Time.now}] "
          msg += "[#{options[:debug_label]}] " if options[:debug_label]
          msg += "Obs partition #{parition_i} (#{partition}) from #{min_id} (#{obs_i} / #{partition_total_entries}, #{( obs_i.to_f  / partition_total_entries * 100 ).round( 2 )}%)"
          print msg
          print "\r"
          $stdout.flush
        end
        Observation.preload_associations( observations, [
          :user,
          { identifications: [:stored_preferences] },
          { photos: :user },
          :sounds,
          :quality_metrics,
          { observations_places: :place },
          {
            annotations: {
              controlled_attribute: [:labels],
              controlled_value: [:labels]
            },
          },
          :observation_field_values,
          :comments
        ] )
        CSV.open( csv_path, "a" ) do |csv|
          observations.each do |o|
            if @options[:debug]
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
        ASSOC_COLUMNS.each do |association, cols|
          association = association.to_sym
          CSV.open( assoc_csv_paths[association], "a" ) do |csv|
            observations.each do |o|
              o.send( association ).each do |associate|
                csv << cols.map {|col| associate.send( col )}
              end
            end
          end
        end
      end
    end
    csv_path
  end
end

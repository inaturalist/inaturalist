# Custom DelayedJob task for the bulk upload functionality.
class BulkObservationFile
  class BulkObservationException < StandardError
    attr_reader :reason, :row_count, :errors, :tag

    def initialize(reason, row_count = nil, errors = [], tag = nil)
      @reason    = reason
      @row_count = row_count unless row_count.nil?
      @tag       = tag unless tag.nil?

      if errors.empty?
        @errors = [reason]
      else
        @errors = errors
      end
    end
  end

  BASE_COLUMN_COUNT = 8
  IMPORT_BATCH_SIZE = 1000
  MAX_ERROR_COUNT   = 100

  def initialize(observation_file, user_id, options = {})
    @observation_file = observation_file
    @coord_system     = options[:coord_system]
    @user_id          = user_id
    @project_id       = options[:project_id]

    # Try to load the specified project.
    if @project_id.blank?
      project = nil
    else
      project = Project.find_by_id( @project_id )
      if project.nil?
        e = BulkObservationException.new('Specified project not found')
        Emailer.delay.bulk_observation_error(user, File.basename(observation_file), e).deliver_now
      end
    end

    @custom_field_count = project.nil? ? 0 : project.observation_fields.size
  end

  def user
    @user ||= User.find_by_id( @user_id )
  end

  def project
    @project ||= Project.find_by_id( @project_id )
  end

  def perform
    begin
      # Run a validation check over the file to make sure it's valid CSV.
      validate_file

      # Start adding observations.
      import_file

      # Email uploader to say that the upload has finished.
      Emailer.bulk_observation_success(user, File.basename(@observation_file)).deliver_now
    rescue BulkObservationException => e
      # Collate the errors into a hash for emailing
      error_details = collate_errors(e)

      # puts "error_details: #{error_details.inspect}"
      # Email the uploader with exception details
      Emailer.bulk_observation_error(user, File.basename(@observation_file), error_details).deliver_now
    end
  end

  def validate_file
    row_count = 1
    errors = []

    # Parse the entire observation file looking for possible errors.
    begin
      CSV.foreach(@observation_file, encoding: 'iso-8859-1:utf-8', headers: true) do |row|
        next if skip_row?(row)
        
        # Look for the species and flag it if it's not found.
        taxon = Taxon.single_taxon_for_name(row[0])
        if taxon.nil?
          errors << BulkObservationException.new("Single taxon not found: #{row[0]}", row_count + 1, [], 'species_not_found')
        end

        # Check the validity of the observation
        obs = new_observation(row)
        unless obs.valid?
          errors << BulkObservationException.new('Observation is not valid', row_count + 1, obs.errors)
        end

        # Increment the row count.
        row_count = row_count + 1

        # Stop if we have reached our max error count
        break if errors.count >= MAX_ERROR_COUNT
      end
    rescue CSV::MalformedCSVError => e
      line = e.message[/line (\d+)/, 1]
      errors << BulkObservationException.new(e.message, line, [e])
    end
    if errors.count > 0
      raise BulkObservationException.new(
        I18n.t(:we_tried_to_process_your_upload_named_filename, :filename => File.basename(@observation_file)), 
        nil, 
        errors)
    end
    if row_count == 0
      raise BulkObservationException.new("The observation file '#{File.basename(@observation_file)}' was empty.")
    end
  end

  # Import the observations in the file, and add to the specified project.
  def import_file
    row_count = 1
    observations = []
    ActiveRecord::Base.transaction do
      CSV.foreach(@observation_file, encoding: 'iso-8859-1:utf-8', headers: true) do |row|
        next if skip_row?(row)

        # Add the observation file name as a tag for identification purposes.
        tags = row[6].blank? ? [] : row[6].split(',')
        tags << File.basename(@observation_file)
        row[6] = tags.join(',')

        obs = new_observation(row)
        begin
          # Try to save the observation
          obs.save!

          # Add this observation to a list for later importing to the project.
          observations << obs

          # Increment the row count so we can tell them where any errors are.
          row_count = row_count + 1
        rescue ActiveRecord::RecordInvalid
          raise BulkObservationException.new('Invalid record encountered', row_count)
        end
      end

      # Add all of the observations to the project if a project was specified
      if project
        observations.each do |obs|
          project.project_observations.create(:observation => obs)
        end

        # Manually update counter caches.
        ProjectUser.update_observations_counter_cache_from_project_and_user(project.id, user.id)
        ProjectUser.update_taxa_counter_cache_from_project_and_user(project.id, user.id)
        Project.update_observed_taxa_count(project.id)

        # Do a mass refresh of the project taxa.
        Project.refresh_project_list(project.id,
          taxa: observations.collect(&:taxon_id).uniq,
          add_new_taxa: true)
      end
    end
    Observation.elastic_index!(ids: observations.map(&:id))
  end

  def new_observation(row)
    obs = Observation.new(
      :user               => user,
      :species_guess      => row[0],
      :observed_on_string => row[1],
      :description        => row[2],
      :place_guess        => row[3],
      :time_zone          => user.time_zone,
      :tag_list           => row[6],
      :geoprivacy         => row[7],
    )

    # If a coordinate system other than WGS84 is in use
    # set the correct fields for transformation.
    if @coord_system.nil?
      obs.latitude  = row[4]
      obs.longitude = row[5]
    else
      obs.geo_x = row[5]
      obs.geo_y = row[4]
      obs.coordinate_system = @coord_system
    end

    # Are we adding to a specific project?
    unless project.nil?
      project.project_observation_fields.each do |pof|
        value = row[pof.observation_field.name]
        if value.blank?
          if pof.required
            obs.custom_field_errors ||= []
            obs.custom_field_errors << "#{pof.observation_field.name} is required"
          end
        else
          obs.observation_field_values.build(:observation_field_id => pof.observation_field_id, :value => value)
        end
      end
    end

    # Skip some expensive post-save tasks
    obs.skip_refresh_check_lists = true
    obs.skip_refresh_lists       = true
    obs.skip_indexing            = true
    obs.bulk_import              = true

    obs
  end

  def skip_row?(row)
    row.blank? || row[0].to_s =~ /^\s*\#/ || row.fields.reject{|s| s.blank?}.blank?
  end

  def collate_errors(exception)
    # enumerate the exceptions and collate error messages
    field_options = {}
    errors = {}
    exception.errors.each do |e|
      if e.errors.is_a?(ActiveModel::Errors)
        e.errors.each do |field, error|
          errors[field] ||= {}
          full_error = e.errors.full_message(field, error)
          errors[field][full_error] ||= []
          errors[field][full_error] << e.row_count
        end
      elsif !e.tag.nil?
        e.errors.each do |error|
          errors[e.tag] ||= {}
          errors[e.tag][error] ||= []
          errors[e.tag][error] << e.row_count
        end
      else
        e.errors.each do |error|
          errors['base'] ||= {}
          errors['base'][error] ||= []
          errors['base'][error] << e.row_count
        end
      end
    end

    {
      reason: exception.reason,
      errors: errors.stringify_keys.sort_by { |k, v| k },
      field_options: field_options
    }
  end

  def max_attempts
    1
  end

end

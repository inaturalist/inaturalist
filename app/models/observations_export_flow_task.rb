#encoding: utf-8
class ObservationsExportFlowTask < FlowTask
  validate :must_have_query
  validate :must_have_reasonable_number_of_rows
  validate :must_be_the_only_active_export, on: :create
  validates_presence_of :user_id

  MAX_OBSERVATIONS = 200000

  class ObservationsExportError < StandardError; end
  class ObservationsExportNotSaved < ObservationsExportError; end
  class ObservationsExportDeleted < ObservationsExportError; end

  before_save do |record|
    record.redirect_url = UrlHelper.export_observations_path
  end

  def must_have_query
    if params.keys.blank?
      errors.add( :base, :must_have_query )
    end  
  end

  def must_have_reasonable_number_of_rows
    if observations_count > MAX_OBSERVATIONS
      errors.add( :base, :must_have_reasonable_number_of_rows )
    end
  end

  def must_be_the_only_active_export
    if ObservationsExportFlowTask.where( user_id: user_id ).
        where( "finished_at IS NULL AND error IS NULL" ).
        exists?
      errors.add( :user_id, :already_has_an_export_in_progress )
    end
  end

  def to_s
    "<#{self.class.name} #{id}>"
  end

  def run(run_options = {})
    @logger = run_options[:logger] if run_options[:logger]
    @debug = run_options[:debug]
    unless persisted?
      raise ObservationsExportNotSaved.new( "Export must be saved before being run" )
    end
    update(finished_at: nil, error: nil, exception: nil)
    outputs.each(&:destroy)
    outputs.reload
    query = inputs.first.extra[:query]
    format = options[:format]
    # if using makara, release stuck primary connections as
    # the following queries can and should be run against replicas
    if ActiveRecord::Base.connection.respond_to?(:enable_context_refresh)
      Makara::Context.release_all
    end
    archive_path = case format
    when 'json'
      json_archive
    else
      csv_archive
    end
    logger.info "ObservationsExportFlowTask #{id}: Created archive at #{archive_path}" if @debug
    File.open( archive_path ) do |f|
      self.outputs.create!(:file => f)
    end
    logger.info "ObservationsExportFlowTask #{id}: Created outputs" if @debug
    # The user may have requested an email confirmation after this run started
    reload
    if options[:email]
      Emailer.observations_export_notification(self).deliver_now
      logger.info "ObservationsExportFlowTask #{id}: Emailed user #{user_id}" if @debug
    end
    true
  rescue Exception => e
    exception_string = [ e.class, e.message ].join(" :: ")
    logger.error "ObservationsExportFlowTask #{id}: Error: #{exception_string}" if @debug
    update(
      finished_at: Time.now,
      error: "Error",
      exception: [ exception_string, e.backtrace ].join("\n")
    )
    # The user may have requested an email confirmation after this run started
    reload
    if options[:email]
      Emailer.observations_export_failed_notification(self).deliver_now
      logger.error "ObservationsExportFlowTask #{id}: Emailed user #{user_id} about error" if @debug
    end
    false
  end

  def preloads
    includes = [
      { user: :friendships },
      { identifications: [:stored_preferences] },
      :project_observations
    ]
    if export_columns.detect{|c| c == "common_name"}
      includes << { taxon: { taxon_names: :place_taxon_names } }
    end
    if export_columns.detect{|c| c =~ /^ident_by_/}
      includes[1][:identifications] = [:stored_preferences, :user]
    end
    if export_columns.detect{|c| c =~ /^place.*_name/}
      includes << { observations_places: :place }
    end
    includes << { observation_field_values: :observation_field }
    if export_columns.detect{ |c| c == "image_url" }
      includes << { photos: [:user, :flags, :file_prefix, :file_extension, :moderator_actions] }
    end
    if export_columns.detect{ |c| c == "sound_url" }
      includes << { sounds: [:user, :flags, :moderator_actions] }
    end
    includes << :quality_metrics if export_columns.detect{ |c| c == "captive_cultivated" }
    includes
  end

  def observations_count
    return 0 if params.blank?
    search_params = Observation.get_search_params( params.merge( per_page: 1 ) )
    search_params[:track_total_hits] = true
    Observation.elastic_query( search_params ).total_entries
  end

  def for_each_observation( search_params )
    batch_i = 0
    obs_i = 0
    site = user.site || Site.default
    Observation.search_in_batches( search_params ) do |batch|
      if @debug
        logger.info
        logger.info "BATCH #{batch_i}"
        logger.info
      end
      unless FlowTask.where( id: id ).exists?
        raise ObservationsExportDeleted.new( "Export was deleted during its run" )
      end
      Observation.preload_associations(batch, preloads)
      batch.each do |observation|
        logger.info "Obs #{obs_i} (#{observation.id})" if @debug
        observation.localize_locale = user.locale || site.locale
        observation.localize_place = user.place || site.place
        yield observation
        obs_i += 1
        logger.info "Finished Obs #{obs_i} (#{observation.id})" if @debug
      end
      batch_i += 1
    end
  end

  def json_archive
    json_path = File.join(work_path, "#{basename}.json")
    json_opts = { only: export_columns, include: [ :observation_field_values, :photos ] }
    site = user.site || Site.default
    FileUtils.mkdir_p(File.dirname(json_path), mode: 0755)
    search_params = params.merge( viewer: user, authenticate: user )
    File.open( json_path, "w" ) do |f|
      f << "["
      first = true
      for_each_observation( search_params ) do |observation|
        f << ',' unless first
        first = false
        json = observation.to_json(json_opts).sub(/^\[/, "").sub(/\]$/, "")
        f << json
      end
      f << "]"
    end
    zip_path = File.join(work_path, "#{basename}.json.zip")
    system "cd #{work_path} && zip -qr #{basename}.json.zip *"
    zip_path
  end

  def csv_archive
    csv_path = File.join(work_path, "#{basename}.csv")
    fname = "#{basename}.csv"
    fpath = csv_path
    FileUtils.mkdir_p(File.dirname(fpath), mode: 0755)
    columns = export_columns
    search_params = params.merge( viewer: user, authenticate: user )
    CSV.open(fpath, "w") do |csv|
      csv << columns.map {|c| CGI.unescape( c ) }
      for_each_observation( search_params ) do |observation|
        coordinates_viewable = observation.coordinates_viewable_by?( user )
        csv << columns.map do |c|
          c = "cached_tag_list" if c == "tag_list"
          if c =~ /^private_/ && !coordinates_viewable
            nil
          else
            observation.send(c) rescue nil
          end
        end
      end
    end
    zip_path = File.join(work_path, "#{basename}.csv.zip")
    system "cd #{work_path} && zip -qr #{basename}.csv.zip *"
    zip_path
  end

  def basename
    "observations-#{id}"
  end

  def work_path(options = {})
    if options[:force] || @work_path.blank?
      @work_path = File.join(Dir::tmpdir, "#{basename}-#{Time.now.to_i}")
    end
    @work_path
  end

  def export_output
    outputs.first
  end

  def query
    @query ||= (inputs.first && inputs.first.extra[:query])
  end

  def params
    @params ||= Rack::Utils.parse_nested_query(query).symbolize_keys
  end

  def export_columns
    exp_columns = options[:columns] || []
    exp_columns = exp_columns.to_h.select{|k,v| v == "1"}.keys if exp_columns.is_a?(Hash) || exp_columns.is_a?(ActionController::Parameters)
    exp_columns = Observation::CSV_COLUMNS if exp_columns.blank?
    ofv_columns = exp_columns.select{|c| c.index("field:")}
    ident_columns = exp_columns.select{|c| c.index("ident_by_" )}
    (exp_columns & Observation::ALL_EXPORT_COLUMNS) + ofv_columns + ident_columns
  end

  def enqueue_options
    opts = {}
    # Giant exports can really bog things down, so manage queue and priority
    count = observations_count
    opts[:priority] = if count > 1000
      USER_INTEGRITY_PRIORITY
    else
      NOTIFICATION_PRIORITY
    end
    opts[:queue] = "csv" if count > 1000
    opts[:unique_hash] = {'ObservationsExportFlowTask': id}
    opts
  end

  def logger
    @logger ||= Rails.logger
  end
end

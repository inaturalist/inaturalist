#encoding: utf-8
class ObservationsExportFlowTask < FlowTask
  validate :must_have_query
  validate :must_have_primary_filter
  validate :must_have_reasonable_number_of_rows
  validates_presence_of :user_id

  before_save do |record|
    record.redirect_url = FakeView.export_observations_path
  end

  def must_have_query
    if params.keys.blank?
      errors.add(:base, "Query cannot be blank")
    end  
  end

  def must_have_primary_filter
    unless params[:iconic_taxa] || 
           params[:iconic_taxon_id] || 
           params[:taxon_id] || 
           params[:place_id] || 
           params[:user_id] || 
           params[:q] || 
           params[:projects] ||
           params.keys.detect{|k| k =~ /^field:/}
      errors.add(:base, "You must specify a taxon, place, user, or search query")
    end
  end

  def must_have_reasonable_number_of_rows
    if observations_count > 200000
      errors.add(:base, "Exports cannot contain more than 200,000 observations")
    end
  end

  def to_s
    "<#{self.class.name} #{id}>"
  end

  def run(run_options = {})
    # site will be looked up tons of times in TaxonName.choose_common_name,
    # so store it in CONFIG
    CONFIG.site ||= Site.find_by_id(CONFIG.site_id) if CONFIG.site_id
    @logger = run_options[:logger] if run_options[:logger]
    @debug = run_options[:debug]
    update_attributes(finished_at: nil, error: nil, exception: nil)
    outputs.each(&:destroy)
    query = inputs.first.extra[:query]
    format = options[:format]
    archive_path = case format
    when 'json'
      json_archive
    else
      csv_archive
    end
    logger.info "ObservationsExportFlowTask #{id}: Created archive at #{archive_path}" if @debug
    open(archive_path) do |f|
      self.outputs.create!(:file => f)
    end
    logger.info "ObservationsExportFlowTask #{id}: Created outputs" if @debug
    if options[:email]
      Emailer.observations_export_notification(self).deliver_now
      logger.info "ObservationsExportFlowTask #{id}: Emailed user #{user_id}" if @debug
    end
    true
  rescue Exception => e
    exception_string = [ e.class, e.message ].join(" :: ")
    logger.error "ObservationsExportFlowTask #{id}: Error: #{exception_string}" if @debug
    update_attributes(finished_at: Time.now,
      error: "Error",
      exception: [ exception_string, e.backtrace ].join("\n"))
    if options[:email]
      Emailer.observations_export_failed_notification(self).deliver_now
      logger.error "ObservationsExportFlowTask #{id}: Emailed user #{user_id} about error" if @debug
    end
    false
  end

  def preloads
    includes = [ :user ]
    if export_columns.detect{|c| c == "common_name"}
      includes << { taxon: { taxon_names: :place_taxon_names } }
    end
    includes << { observation_field_values: :observation_field }
    includes << :photos if export_columns.detect{ |c| c == 'image_url' }
    includes << :quality_metrics if export_columns.detect{ |c| c == 'captive_cultivated' }
    includes
  end

  def observations_count
    return 0 if params.blank?
    Observation.elastic_query(params.merge(per_page: 1)).total_entries
  end

  def json_archive
    json_path = File.join(work_path, "#{basename}.json")
    json_opts = { only: export_columns, include: [ :observation_field_values, :photos ] }
    FileUtils.mkdir_p(File.dirname(json_path), mode: 0755)
    open(json_path, "w") do |f|
      f << "["
      first = true
      Observation.search_in_batches(params) do |batch|
        Observation.preload_associations(batch, preloads)
        batch.each do |observation|
          f << ',' unless first
          first = false
          json = observation.to_json(json_opts).sub(/^\[/, "").sub(/\]$/, "")
          f << json
        end
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
    CSV.open(fpath, "w") do |csv|
      csv << columns
      batch_i = 0
      obs_i = 0
      Observation.search_in_batches(params) do |batch|
        if @debug
          logger.info
          logger.info "BATCH #{batch_i}"
          logger.info
        end
        Observation.preload_associations(batch, preloads)
        batch.each do |observation|
          logger.info "Obs #{obs_i} (#{observation.id})" if @debug
          csv << columns.map do |c|
            c = "cached_tag_list" if c == "tag_list"
            if c =~ /^private_/ && !observation.coordinates_viewable_by?( user )
              nil
            else
              observation.send(c) rescue nil
            end
          end
          obs_i += 1
        end
        batch_i += 1
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
    exp_columns = exp_columns.select{|k,v| v == "1"}.keys if exp_columns.is_a?(Hash)
    exp_columns = Observation::CSV_COLUMNS if exp_columns.blank?
    ofv_columns = exp_columns.select{|c| c.index("field:")}
    exp_columns = (exp_columns & Observation::ALL_EXPORT_COLUMNS) + ofv_columns
    viewer_curates_project = if projects = params[:projects]
      if projects.size == 1
        project = Project.find(projects[0]) rescue nil
        project.curated_by?(user) if project
      end
    end
    viewer_is_owner = if user_id = params[:user_id]
      if filter_user = User.find_by_id(user_id) || User.find_by_login(user_id)
        filter_user === user
      end
    end
    unless viewer_curates_project || viewer_is_owner
      exp_columns = exp_columns.select{|c| c !~ /^private_/}
    end
    exp_columns
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
    opts[:queue] = "slow" if count > 10000
    opts[:unique_hash] = {'ObservationsExportFlowTask': id}
    opts
  end

  def logger
    @logger ||= Rails.logger
  end
end

#encoding: utf-8
class ObservationsExportFlowTask < FlowTask
  validate :must_have_query
  validate :must_have_primary_filter
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

  def to_s
    "<#{self.class.name} #{id}>"
  end

  def run
    outputs.each(&:destroy)
    query = inputs.first.extra[:query]
    format = options[:format]
    @observations = observations_scope
    archive_path = case format
    when 'json'
      json_archive
    else
      csv_archive
    end
    open(archive_path) do |f|
      self.outputs.create!(:file => f)
    end

    if options[:email]
      Emailer.observations_export_notification(self).deliver_now
    end
    true
  end

  def observations_scope
    if params.blank?
      Observation.where("1 = 2")
    else
      # remove order, b/c it won't work with find_each and seems to cause errors in DJ
      scope = Observation.query(params).includes(:user).reorder(nil)
      scope = scope.includes(:taxon => :taxon_names) if export_columns.detect{|c| c == "common_name"}
      scope = scope.includes(:observation_field_values => :observation_field) if export_columns.detect{|c| c =~ /field\:/}
      scope = scope.includes(:observation_photos => :photo) if export_columns.detect{|c| c == 'image_url'}
      scope = scope.includes(:quality_metrics) if export_columns.detect{|c| c == 'captive_cultivated'}
      scope
    end
  end

  def json_archive
    json_path = File.join(work_path, "#{basename}.json")
    json_opts = {:only => export_columns, :include => [:observation_field_values, :photos]}
    FileUtils.mkdir_p File.dirname(json_path), :mode => 0755
    open(json_path, 'w') do |f|
      f << '['
      first = true
      @observations.find_in_batches do |b|
        f << ',' unless first
        first = false
        json = b.to_json(json_opts).sub(/^\[/, '').sub(/\]$/, '')
        f << json
      end
      f << ']'
    end
    zip_path = File.join(work_path, "#{basename}.json.zip")
    system "cd #{work_path} && zip -qr #{basename}.json.zip *"
    zip_path
  end

  def csv_archive
    csv_path = File.join(work_path, "#{basename}.csv")
    path = Observation.generate_csv(@observations, :fname => "#{basename}.csv", :path => csv_path, :columns => export_columns)
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
    @query ||= inputs.first.extra[:query]
  end

  def params
    @params ||= Rack::Utils.parse_nested_query(query).symbolize_keys
  end

  def export_columns
    export_columns = options[:columns] || []
    export_columns = export_columns.select{|k,v| v == "1"}.keys if export_columns.is_a?(Hash)
    export_columns = Observation::CSV_COLUMNS if export_columns.blank?
    ofv_columns = export_columns.select{|c| c.index("field:")}
    export_columns = (export_columns & Observation::ALL_EXPORT_COLUMNS) + ofv_columns
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
      export_columns = export_columns.select{|c| c !~ /^private_/}
    end
    export_columns
  end

  def enqueue_options
    opts = {}
    # Giant exports can really bog things down, so manage queue and priority
    count = observations_scope.count
    opts[:priority] = if count > 1000
      USER_INTEGRITY_PRIORITY
    else
      NOTIFICATION_PRIORITY
    end
    opts[:queue] = "slow" if count > 10000
    opts[:unique_hash] = {'ObservationsExportFlowTask': id}
    opts
  end
end

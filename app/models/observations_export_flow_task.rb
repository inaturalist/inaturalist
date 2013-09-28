#encoding: utf-8
class ObservationsExportFlowTask < FlowTask
  validate :must_have_query
  validate :must_have_primary_filter

  after_save do |record|
    ObservationsExportFlowTask.update_all(
      {:redirect_url => FakeView.export_observations_path(:flow_task_id => id)}, 
      ["id = ?", id]
    )
  end

  def must_have_query
    if params.keys.blank?
      errors.add(:base, "Query cannot be blank")
    end  
  end

  def must_have_primary_filter
    unless params[:iconic_taxa] || params[:iconic_taxon_id] || params[:taxon_id] || params[:place_id] || params[:user_id] || params[:q]
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
    @observations = if params.blank?
      Observation.where("1 = 2")
    else
      # remove order, b/c it won't work with find_each and seems to cause errors in DJ
      Observation.query(params).reorder(nil)
    end
    archive_path = case format
    when 'shapefile'
      shapefile_archive
    when 'kml'
      kml_archive
    else
      csv_archive
    end
    open(archive_path) do |f|
      self.outputs.create!(:file => f)
    end
  end

  def csv_archive
    csv_path = File.join(work_path, "#{basename}.csv")
    path = Observation.generate_csv(@observations, :fname => "#{basename}.csv", :path => csv_path)
    zip_path = File.join(work_path, "#{basename}.csv.zip")
    system "cd #{work_path} && zip -r #{basename}.csv.zip *"
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
end

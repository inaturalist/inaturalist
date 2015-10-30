class Project < ActiveRecord::Base

  include ActsAsElasticModel

  belongs_to :user
  belongs_to :place, :inverse_of => :projects
  has_many :project_users, :dependent => :delete_all
  has_many :project_observations, :dependent => :destroy
  has_many :project_invitations, :dependent => :destroy
  has_many :project_user_invitations, :dependent => :delete_all
  has_many :users, :through => :project_users
  has_many :observations, :through => :project_observations
  has_one :project_list, :dependent => :destroy
  has_many :listed_taxa, :through => :project_list
  has_many :taxa, :through => :listed_taxa
  has_many :project_assets, :dependent => :destroy
  has_one :custom_project, :dependent => :destroy
  has_many :project_observation_fields, -> { order("position") }, :dependent => :destroy, :inverse_of => :project
  has_many :observation_fields, :through => :project_observation_fields
  has_many :posts, :as => :parent, :dependent => :destroy
  has_many :journal_posts, :class_name => "Post", :as => :parent
  has_many :assessments, :dependent => :destroy
  
  before_save :strip_title
  before_save :unset_show_from_place_if_no_place
  after_create :create_the_project_list
  after_save :add_owner_as_project_user
  
  has_rules_for :project_users, :rule_class => ProjectUserRule
  has_rules_for :project_observations, :rule_class => ProjectObservationRule

  has_subscribers :to => {
    :posts => {:notification => "created_project_post"},
    :project_users => {:notification => "curator_change"}
  }

  extend FriendlyId
  friendly_id :title, :use => [ :slugged, :history, :finders ], :reserved_words => ProjectsController.action_methods.to_a
  
  preference :count_from_list, :boolean, :default => false
  preference :place_boundary_visible, :boolean, :default => false
  preference :count_by, :string, :default => 'species'
  preference :range_by_date, :boolean, :default => false
  preference :aggregation, :boolean, default: false
  
  SUBMISSION_BY_ANYONE = 'any'
  SUBMISSION_BY_CURATORS = 'curators'
  SUBMISSION_MODELS = [SUBMISSION_BY_ANYONE, SUBMISSION_BY_CURATORS]
  preference :submission_model, :string, default: SUBMISSION_BY_ANYONE

  MEMBERSHIP_OPEN = 'open'
  MEMBERSHIP_INVITE_ONLY = 'inviteonly'
  MEMBERSHIP_MODELS = [MEMBERSHIP_OPEN, MEMBERSHIP_INVITE_ONLY]
  preference :membership_model, :string, :default => MEMBERSHIP_OPEN
  
  accepts_nested_attributes_for :project_observation_fields, :allow_destroy => true
  
  validates_length_of :title, :within => 1..100
  validates_presence_of :user
  validates_format_of :event_url, :with => URI.regexp, 
    :message => "should look like a URL, e.g. #{CONFIG.site_url}",
    :allow_blank => true
  validates_presence_of :start_time, :if => lambda {|p| p.project_type == BIOBLITZ_TYPE}, :message => "can't be blank for a bioblitz"
  validates_presence_of :end_time, :if => lambda {|p| p.project_type == BIOBLITZ_TYPE}, :message => "can't be blank for a bioblitz"
  validate :place_with_boundary, :if => lambda {|p| p.project_type == BIOBLITZ_TYPE}
  validate :one_year_time_span, :if => lambda {|p| p.project_type == BIOBLITZ_TYPE}, :unless => "errors.any?"
  validate :aggregation_preference_allowed?

  def aggregation_preference_allowed?
    return true unless prefers_aggregation?
    return true if aggregation_allowed?
    errors.add(:base, I18n.t(:project_aggregator_filter_error))
    true
  end
  
  scope :featured, -> { where("featured_at IS NOT NULL") }
  scope :in_group, lambda {|name| where(:group => name) }
  scope :near_point, lambda {|latitude, longitude|
    latitude = latitude.to_f
    longitude = longitude.to_f
    where("ST_Distance(ST_Point(projects.longitude, projects.latitude), ST_Point(#{longitude}, #{latitude})) < 5").
    order("ST_Distance(ST_Point(projects.longitude, projects.latitude), ST_Point(#{longitude}, #{latitude}))")
  }
  scope :from_source_url, lambda {|url| where(:source_url => url) }
  scope :in_place, lambda{|place|
    place = Place.find(place) unless place.is_a?(Place) rescue nil
    if place
      conditions = place.descendant_conditions.to_sql
      conditions += " OR places.id = #{place.id}"
      joins(:place).where(conditions)
    else
      where("1 = 2")
    end
  }
  
  has_attached_file :icon, 
    :styles => { :thumb => "48x48#", :mini => "16x16#", :span1 => "30x30#", :span2 => "70x70#", :original => "1024x1024>" },
    :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :url => "#{ CONFIG.attachments_host }/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :default_url => "/attachment_defaults/general/:style.png"
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"

  if Rails.env.production?
    has_attached_file :cover,
      :storage => :s3,
      :s3_credentials => "#{Rails.root}/config/s3.yml",
      :s3_host_alias => CONFIG.s3_bucket,
      :bucket => CONFIG.s3_bucket,
      :path => "projects/:id-cover.:extension",
      :url => ":s3_alias_url",
      :default_url => ""
  else
    has_attached_file :cover,
      :path => ":rails_root/public/attachments/:class/:id-cover.:extension",
      :url => "#{ CONFIG.s3_host }/attachments/:class/:id-cover.:extension",
      :default_url => ""
  end
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /octet-stream/], :message => "must be JPG or PNG"
  validate :cover_dimensions, :unless => "errors.any?"
  
  ASSESSMENT_TYPE = 'assessment'
  BIOBLITZ_TYPE = 'bioblitz'
  PROJECT_TYPES = [ASSESSMENT_TYPE, BIOBLITZ_TYPE]
  RESERVED_TITLES = ProjectsController.action_methods
  MAP_TYPES = %w(roadmap terrain satellite hybrid)
  validates_exclusion_of :title, :in => RESERVED_TITLES + %w(user)
  validates_uniqueness_of :title
  validates_inclusion_of :map_type, :in => MAP_TYPES

  acts_as_spammable fields: [ :title, :description ],
                    comment_type: "item-description",
                    automated: false

  def place_with_boundary
    unless PlaceGeometry.where(:place_id => place_id).exists?
      errors.add(:place_id, "must be set and have a boundary for a bioblitz")
    end
  end

  def one_year_time_span
    if end_time - start_time > 366.days
      errors.add(:end_time, "must be less than one year after the start time")
    end
  end
  
  def to_s
    "<Project #{id} #{title}>"
  end

  def start_time=(value)
    if value.is_a?(String)
      super(Chronic.parse(value))
    else
      super
    end
  end

  def end_time=(value)
    if value.is_a?(String)
      super(Chronic.parse(value))
    else
      super
    end
  end
  
  def strip_title
    self.title = title.strip
    true
  end

  def unset_show_from_place_if_no_place
    self.show_from_place = false if place.blank? || place.check_list.blank?
    true
  end

  def cover_dimensions
    return true unless cover.queued_for_write[:original]
    dimensions = Paperclip::Geometry.from_file(cover.queued_for_write[:original].path)
    if dimensions.width != 950 || dimensions.height > 400
      errors.add(I18n.t(:cover), I18n.t(:image_must_be_exactly))
    end
  end
  
  def add_owner_as_project_user(options = {})
    return true unless user_id_changed? || options[:force]
    if pu = project_users.where(:user_id => user_id).first
      pu.update_attributes(:role => ProjectUser::MANAGER)
    else
      self.project_users.create(:user => user, :role => ProjectUser::MANAGER, :skip_updates => true)
    end
    true
  end
  
  def create_the_project_list
    create_project_list(:project => self)
    true
  end
  
  def editable_by?(user)
    return false if user.blank?
    return true if user.id == user_id || user.is_admin?
    pu = user.project_users.where(project_id: id).first
    pu && pu.is_manager?
  end
  
  def curated_by?(user)
    return false if user.blank?
    return true if user.is_admin?
    project_users.curators.exists?(:user_id => user.id) || project_users.managers.exists?(:user_id => user.id)
  end
  
  def rule_place
    project_observation_rules.where(operator: "observed_in_place?").first.try(:operand)
  end

  def rule_taxon
    @rule_taxon ||= rule_taxa.first
  end

  def rule_taxa
    @rule_taxa ||= project_observation_rules.where(:operator => "in_taxon?").map(&:operand).compact
  end
  
  def icon_url
    return nil unless icon.file?
    url = icon.url(:span2)
    url = URI.join(CONFIG.site_url, url).to_s unless url =~ /^http/
    url
  end
  
  def project_observation_rule_terms
    project_observation_rules.map{|por| por.terms}.join('|')
  end

  def matching_project_observation_rule_terms
    matching_project_observation_rules.map{|por| por.terms}.join('|')
  end

  def matching_project_observation_rules
    matching_operators = %w(in_taxon? observed_in_place? on_list? identified? georeferenced?)
    project_observation_rules.select{|rule| matching_operators.include?(rule.operator)}
  end
  
  def project_observations_count
    project_observations.count
  end
  
  def featured_at_utc
    featured_at.try(:utc)
  end
  
  def tracking_code_allowed?(code)
    return false if code.blank?
    return false if tracking_codes.blank?
    tracking_codes.split(',').map{|c| c.strip}.include?(code)
  end

  def observations_matching_rules
    scope = Observation.all
    project_observation_rules.each do |rule|
      case rule.operator
      when "in_taxon?"
        scope = scope.of(rule.operand)
      when "observed_in_place?"
        scope = scope.in_place(rule.operand)
      when "on_list?"
        scope = scope.where("observations.taxon_id = listed_taxa.taxon_id").
          joins("JOIN listed_taxa ON listed_taxa.list_id = #{project_list.id}")
      when "identified?"
        scope = scope.where("observations.taxon_id IS NOT NULL")
      when "georeferenced"
        scope = scope.where("observations.geom IS NOT NULL")
      end
    end
    scope
  end

  def observations_url_params
    params = {:place_id => place_id}
    if start_time && end_time
      if prefers_range_by_date?
        params.merge!(
          d1: Date.parse(start_time.in_time_zone(user.time_zone).iso8601.split('T').first).to_s,
          d2: Date.parse(end_time.in_time_zone(user.time_zone).iso8601.split('T').first).to_s
        )
      else
        params.merge!(:d1 => start_time.in_time_zone(user.time_zone).iso8601, :d2 => end_time.in_time_zone(user.time_zone).iso8601)
      end
    end
    taxon_ids = []
    project_observation_rules.each do |rule|
      case rule.operator
      when "in_taxon?"
        taxon_ids << rule.operand_id
      when "observed_in_place?"
        # Ignore, we already added the place_id
      when "on_list?"
        params[:list_id] = project_list.id
      when "identified?"
        params[:identified] = true
      when "georeferenced?"
        params[:has] ||= []
        params[:has] << "geo"
      when "has_a_photo?"
        params[:has] ||= []
        params[:has] << "photos"
      when "has_a_sound?"
        params[:has] ||= []
        params[:has] << "sounds"
      when "captive?"
        params[:captive] = true
      when "wild?"
        params[:captive] = false
      end
    end
    taxon_ids.compact.uniq!
    params.merge!(taxon_ids: taxon_ids) unless taxon_ids.blank?
    params
  end

  def cached_slug
    slug
  end

  def should_generate_new_friendly_id?
    title_changed?
  end

  def slug_candidates
    [
      :title,
      [:title, :id]
    ]
  end

  def curators
    users.where("project_users.role = ?", ProjectUser::CURATOR)
  end

  def managers
    users.where("project_users.role = ?", ProjectUser::MANAGER)
  end

  def duplicate
    new_project = dup
    project_observation_fields.each do |pof|
      new_project.project_observation_fields.build(:position => pof.position, 
        :observation_field => pof.observation_field, :required => pof.required)
    end
    project_observation_rules.each do |por|
      new_project.project_observation_rules.build(:operand => por.operand, :operator => por.operator)
    end
    new_project.title = "#{title} copy"
    new_project.custom_project = custom_project.dup unless custom_project.blank?
    new_project.save!
    listed_taxa.find_each do |lt|
      ListedTaxon.create(:list => new_project.project_list, :taxon_id => lt.taxon_id, :description => lt.description)
    end
    new_project
  end

  def generate_csv(path, columns, options = {})
    project_columns = %w(curator_ident_taxon_id curator_ident_taxon_name curator_ident_user_id curator_ident_user_login tracking_code curator_coordinate_access)
    columns += project_columns
    ofv_columns = self.observation_fields.map{|of| "field:#{of.normalized_name}"}
    columns += ofv_columns
    if options[:viewer]
      options[:viewer].project_users.load
    end
    CSV.open(path, 'w') do |csv|
      csv << columns
      self.project_observations.find_in_batches do |batch|
        ProjectObservation.preload_associations(batch, [
          :stored_preferences,
          curator_identification: [:taxon, :user],
          observation: [{
            identifications: :taxon,
            observation_photos: :photo,
            taxon: {taxon_names: :place_taxon_names},
            observation_field_values: :observation_field,
            project_observations: :stored_preferences,
            user: {project_users: :stored_preferences},
          }, :quality_metrics ]
        ])
        batch.each do |project_observation|
          csv << columns.map {|column| 
            project_observation.to_csv_column(column, :project => self, :viewer => options[:viewer])
          }
        end
      end
    end
  end

  def eventbrite_id
    return if event_url.blank?
    return unless event_url =~ /eventbrite\.com/
    @eventbrite_id ||= URI.parse(event_url).path.split('/').last.to_s.scan(/\d+/).last
  end

  def event_started?
    return nil if start_time.blank?
    start_time < Time.now
  end

  def event_ended?
    return nil if end_time.blank?
    Time.now > end_time
  end

  def event_in_progress?
    return nil if end_time.blank? || start_time.blank?
    start_time < Time.now && end_time > Time.now
  end
  
  def self.default_json_options
    {
      :methods => [:icon_url, :project_observation_rule_terms, :featured_at_utc, :rule_place, :cached_slug, :slug],
      :except => [:tracking_codes]
    }
  end
  
  def self.update_curator_idents_on_make_curator(project_id, project_user_id)
    unless project = Project.find_by_id(project_id)
      return
    end
    unless project_user = project.project_users.find_by_id(project_user_id)
      return
    end
    project.project_observations.joins({ :observation => :identifications }).
      where("project_observations.curator_identification_id IS NULL AND identifications.user_id = ?",
      project_user.user_id).find_each do |po|
      curator_ident = po.observation.identifications.detect{|ident| ident.user_id == project_user.user_id}
      po.update_attributes(:curator_identification => curator_ident)
      ProjectUser.delay(priority: INTEGRITY_PRIORITY,
        unique_hash: { "ProjectUser::update_observations_counter_cache_from_project_and_user":
          [ project_id, po.observation.user_id ] }
      ).update_observations_counter_cache_from_project_and_user(project_id, po.observation.user_id)
      ProjectUser.delay(priority: INTEGRITY_PRIORITY,
        unique_hash: { "ProjectUser::update_taxa_counter_cache_from_project_and_user":
          [ project_id, po.observation.user_id ] }
      ).update_taxa_counter_cache_from_project_and_user(project_id, po.observation.user_id)
    end
  end
  
  def self.update_curator_idents_on_remove_curator(project_id, user_id)
    unless project = Project.find_by_id(project_id)
      return
    end
    
    find_options = if user = User.find_by_id(user_id)
      {
        :include => [:curator_identification, :observation], 
        :conditions => ["identifications.user_id = ?", user.id]
      }
    else
      {
        :include => {:observation => :identifications}, 
        :conditions => "project_observations.curator_identification_id IS NOT NULL"
      }
    end
    
    project_curators = project.project_users.where(role: [ ProjectUser::MANAGER, ProjectUser::CURATOR ])
    project_curator_user_ids = project_curators.map{|pu| pu.user_id}
    
    project.project_observations.where(find_options[:conditions]).joins(find_options[:include]).each do |po|
      curator_ident = po.observation.identifications.detect{|ident| project_curator_user_ids.include?(ident.user_id)}
      po.update_attributes(:curator_identification => curator_ident)
      ProjectUser.delay(priority: INTEGRITY_PRIORITY,
        unique_hash: { "ProjectUser::update_observations_counter_cache_from_project_and_user":
          [ project_id, po.observation.user_id ] }
      ).update_observations_counter_cache_from_project_and_user(project_id, po.observation.user_id)
      ProjectUser.delay(priority: INTEGRITY_PRIORITY,
        unique_hash: { "ProjectUser::update_taxa_counter_cache_from_project_and_user":
          [ project_id, po.observation.user_id ] }
      ).update_taxa_counter_cache_from_project_and_user(project_id, po.observation.user_id)
    end
  end
  
  def self.refresh_project_list(project, options = {})
    unless project.is_a?(Project)
      project = Project.where(id: project).includes(:project_list).first
    end
    
    if project.blank?
      Rails.logger.error "[ERROR #{Time.now}] Failed to refresh list for " + 
        "project #{project} because it doesn't exist."
      return
    end
    
    project.project_list.refresh(options)
  end
  
  def self.update_observed_taxa_count(project_id)
    return unless project = Project.find_by_id(project_id)
    observed_taxa_count = project.project_list.listed_taxa.where("last_observation_id IS NOT NULL").count
    project.update_attributes(:observed_taxa_count => observed_taxa_count)
  end
  
  def self.revoke_project_observations_on_leave_project(project_id, user_id)
    return unless proj = Project.find_by_id(project_id)
    return unless usr = User.find_by_id(user_id)
    proj.project_observations.joins(:observation).where("observations.user_id = ?", usr).find_each do |po|
      po.update_attributes(prefers_curator_coordinate_access: false)
    end
  end

  def self.delete_project_observations_on_leave_project(project_id, user_id)
    return unless proj = Project.find_by_id(project_id)
    return unless usr = User.find_by_id(user_id)
    proj.project_observations.joins(:observation).where("observations.user_id = ?", usr).find_each do |po|
      po.destroy
    end
  end

  def get_observed_listed_taxa_count #numerator on project/show
    if show_from_place?
      if p.preferred_count_by == "species"
      elsif p.preferred_count_by == "leaves"
      else
      end
    else
      if p.preferred_count_by == "species"
      elsif p.preferred_count_by == "leaves"
      else
      end
    end
  end

  def list_observed_and_total #denominator and numerator on project/show
    if show_from_place?
      find_observed_and_total_for_project_from_place
    else
      find_observed_and_total_for_project_not_from_place
    end
  end

  def self.slugs_to_ids(slugs)
    slugs = slugs.split(',') if slugs.is_a?(String)
    [slugs].flatten.compact.map do |p|
      project_id = p if p.is_a? Fixnum
      project_id ||= p.id if p.is_a? Project
      project_id ||= Project.find(p).try(:id) rescue nil
      project_id
    end.compact
  end

  def find_observed_and_total_for_project_from_place
    list = project_list
    observable_list = place.check_list

    listed_taxa_with_duplicates = ListedTaxon.from_place_or_list(list.project.place_id, list.id)

    query = listed_taxa_with_duplicates.select([:id, :taxon_id, :place_id, :last_observation_id])
    results = ActiveRecord::Base.connection.select_all(query)

    listed_taxa_hash = results.inject({}) do |aggregator, listed_taxon|
      aggregator["#{listed_taxon['taxon_id']}"] = listed_taxon['id'] if (aggregator["#{listed_taxon['taxon_id']}"].nil? || listed_taxon['place_id'].nil?)
      aggregator
    end

    listed_taxa_ids = listed_taxa_hash.values.map(&:to_i)
    unpaginated_listed_taxa = listed_taxa_with_duplicates.where("listed_taxa.id IN (?)", listed_taxa_ids)

    unpaginated_listed_taxa = unpaginated_listed_taxa.with_taxonomic_status(true)
    unpaginated_listed_taxa = unpaginated_listed_taxa.with_occurrence_status_levels_approximating_present
    if preferred_count_by == "species"
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_species
    elsif preferred_count_by == "leaves"
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_leaves(unpaginated_listed_taxa.to_sql.sub("AND (taxa.rank_level = 10)", ""))
    end
    
    {numerator: unpaginated_listed_taxa.confirmed_and_not_place_based.count, denominator: unpaginated_listed_taxa.count}
  end

  def find_observed_and_total_for_project_not_from_place
    unpaginated_listed_taxa = ListedTaxon.filter_by_list(project_list.id)
    unpaginated_listed_taxa = unpaginated_listed_taxa.with_taxonomic_status(true)
    if preferred_count_by == "species"
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_species
    elsif preferred_count_by == "leaves"
      unpaginated_listed_taxa = unpaginated_listed_taxa.with_leaves(unpaginated_listed_taxa.to_sql)
    end
    {numerator: unpaginated_listed_taxa.confirmed.count, denominator: unpaginated_listed_taxa.count}
  end

  def generate_bulk_upload_template
    data = {
      I18n.t(:species_guess)             => ['#Lorem', 'Ipsum', 'Dolor'],
      I18n.t(:observation_date)          => ['2013-01-01', '2013-01-01 09:10:11', '2013-01-01T14:40:33'],
      I18n.t(:description)               => ['Description of observation'],
      I18n.t(:location)                  => ['Wellington City'],
      I18n.t(:latitude_slash_y_coord_slash_northing)    => [latitude || -41],
      I18n.t(:longitude_slash_x_coord_slash_easting)   => [longitude || 174],
      I18n.t(:tags)                      => ['Comma,Separated', 'List,Of,Tags'],
      I18n.t(:geoprivacy)                => ["[Leave blank for 'open']", 'Private', 'Obscured'],
    }

    ProjectObservationField.includes(:observation_field).where(:project_id => self.id).order(:position).each do |field|
      name = field.observation_field.name
      name = "#{name}*" if field.required?
      if field.observation_field.allowed_values.blank?
        data[name] = [field.observation_field.datatype]
      else
        data[name] = ["One of #{field.observation_field.allowed_values.split('|').join(', ')}"]
      end
    end

    CSV.generate do |csv|
      csv << data.keys
      csv << ['# A hash mark at the start of a row will mean the entire row is ignored']
      csv << data.collect { |f| f[1][0] }
      csv << data.collect { |f| f[1][1] }
      csv << data.collect { |f| f[1][2] }
    end
  end

  def split_large_array(list)
    list_count = (list.count / 3.0).ceil
    list.in_groups_of(list_count)
  end

  def invite_only?
    preferred_membership_model == MEMBERSHIP_INVITE_ONLY
  end

  def aggregation_allowed?
    return true if place && place.bbox_area < 141
    return true if project_observation_rules.where("operator IN (?)", %w(in_taxon? on_list?)).exists?
    false
  end

  class ProjectAggregatorAlreadyRunning < StandardError; end

  def aggregate_observations(options = {})
    return false unless aggregation_allowed?
    logger = options[:logger] || Rails.logger
    start_time = Time.now
    added = 0
    fails = 0
    logger.info "[INFO #{Time.now}] Starting aggregation for #{self}"
    params = observations_url_params.merge(per_page: 200, not_in_project: id)
    # making sure we only look observations opdated since the last aggregation
    params[:updated_since] = last_aggregated_at.to_s unless last_aggregated_at.nil?
    list = params[:list_id] ? List.find_by_id(params[:list_id]) : nil
    page = 1
    total_entries = nil
    while true
      if options[:pidfile]
        unless File.exists?(options[:pidfile])
          msg = "Project aggregator running without a PID file at #{options[:pidfile]}"
          logger.error "[ERROR #{Time.now}] #{msg}"
          raise ProjectAggregatorAlreadyRunning, msg
        end
        pid = open(options[:pidfile]).read.to_s.strip.to_i
        unless pid == Process.pid
          msg = "Another project aggregator (#{pid}) is already running (this pid: #{Process.id})"
          logger.error "[ERROR #{Time.now}] #{msg}"
          raise ProjectAggregatorAlreadyRunning, msg
        end
      end
      # the list filter will be ignored if the count is over 2000,
      # so we might as well use the faster ES search in that case
      observations = if list && list.listed_taxa.count <= 2000
        # using cached total_entries to avoid many COUNT(*)s on slow queries
        Observation.query(params).paginate(page: page, total_entries: total_entries,
          per_page: observations_url_params[:per_page])
      else
        # setting list_id to nil because we would have used the DB above
        # if we could have, and ES can't handle list_ids
        Observation.elastic_query(params.merge(page: page, list_id: nil))
      end
      break if observations.blank?
      # caching total entries since it should be the same for each page
      total_entries = observations.total_entries if page === 1
      Rails.logger.debug "[DEBUG] Processing page #{observations.current_page} of #{observations.total_pages} for #{slug}"
      observations.each do |o|
        # don't use first_or_create here
        po = ProjectObservation.where(project: self, observation: o).first ||
          ProjectObservation.create(project: self, observation: o)
        if po && !po.errors.any?
          added += 1
        else
          fails += 1
          Rails.logger.debug "[DEBUG] Failed to add #{po} to #{self}: #{po.errors.full_messages.to_sentence}"
        end
      end
      observations = nil
      page += 1
    end
    update_attributes(last_aggregated_at: Time.now)
    logger.info "[INFO #{Time.now}] Finished aggregation for #{self} in #{Time.now - start_time}s, #{added} observations added, #{fails} failures"
  end

  def self.aggregate_observations(options = {})
    # PID file stuff inspired by 
    # http://stackoverflow.com/questions/3983883/how-to-ensure-a-rake-task-only-running-a-process-at-a-time and 
    # http://codeincomplete.com/posts/2014/9/15/ruby_daemons/#separation-of-concerns
    pidfile = File.join(Rails.root, "tmp", "pids", "project_aggregator.pid")
    if File.exists? pidfile
      f = File.open(pidfile, 'r')
      pid = f.read.to_s.strip.to_i
      f.close
      begin
        # send signal 0 to check process status
        Process.kill(0, pid)
        msg = "Project aggegator #{pid} is already running, quitting (this pid: #{Process.pid})"
        Rails.logger.error "[ERROR #{Time.now}] #{msg}"
        raise ProjectAggregatorAlreadyRunning, msg
      rescue Errno::EPERM
        msg = "Project aggegator #{pid} is already running but not owned, quitting (this pid: #{Process.pid})"
        Rails.logger.error "[ERROR #{Time.now}] #{msg}"
        raise ProjectAggregatorAlreadyRunning, msg
      rescue Errno::ESRCH
        # Process is not running even though pidfile is there, so delete it
        Rails.logger.info "[INFO #{Time.now}] Deleting #{pidfile} b/c process #{pid} is not running"
        File.delete pidfile
      end
    end
    File.open(pidfile, 'w') {|f| f.puts Process.pid}
    logger = options[:logger] || Rails.logger
    start_time = Time.now
    num_projects = 0
    logger.info "[INFO #{Time.now}] Starting Project.aggregate_observations"
    Project.joins(:stored_preferences).where("preferences.name = 'aggregation' AND preferences.value = 't'").find_each do |p|
      next unless p.aggregation_allowed? && p.prefers_aggregation?
      p.aggregate_observations(logger: logger, pidfile: pidfile)
      num_projects += 1
    end
    logger.info "[INFO #{Time.now}] Finished Project.aggregate_observations in #{Time.now - start_time}s, #{num_projects} projects"
    Rails.logger.info "[INFO #{Time.now}] Deleting #{pidfile} after complete aggregation"
    File.delete(pidfile) if File.exists?(pidfile)
  rescue => e
    File.delete(pidfile) if File.exists?(pidfile) && !e.is_a?(ProjectAggregatorAlreadyRunning)
    Rails.logger.error "[ERROR #{Time.now}] Deleting #{pidfile} after error: #{e}"
    raise e
  end
end

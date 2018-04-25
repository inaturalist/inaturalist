class Project < ActiveRecord::Base

  include ActsAsElasticModel

  belongs_to :user
  belongs_to :place, :inverse_of => :projects
  has_many :project_users, :dependent => :delete_all, :inverse_of => :project
  has_many :project_observations, :dependent => :delete_all
  has_many :project_invitations, :dependent => :destroy
  has_many :project_user_invitations, :dependent => :delete_all
  has_many :users, :through => :project_users
  has_many :observations, :through => :project_observations
  has_one :project_list, :dependent => :destroy
  has_many :listed_taxa, :through => :project_list
  has_many :taxa, :through => :listed_taxa
  has_many :project_assets, :dependent => :delete_all
  has_one :custom_project, :dependent => :delete
  has_many :project_observation_fields, -> { order("position") }, :dependent => :destroy, :inverse_of => :project
  has_many :observation_fields, :through => :project_observation_fields
  has_many :posts, :as => :parent, :dependent => :destroy
  has_many :journal_posts, :class_name => "Post", :as => :parent
  has_many :assessments, :dependent => :destroy
  
  before_save :strip_title
  before_save :reset_last_aggregated_at
  before_save :remove_times_from_non_bioblitzes
  after_create :create_the_project_list
  after_save :add_owner_as_project_user
  before_update :set_updated_at_if_preferences_changed


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
  preference :display_checklist, :boolean, :default => false
  preference :range_by_date, :boolean, :default => false
  preference :aggregation, :boolean, default: false
  preference :banner_color, :string
  preference :hide_title, :boolean, default: false
  preference :rule_quality_grade, :string
  preference :rule_photos, :boolean
  preference :rule_sounds, :boolean
  preference :rule_observed_on, :string
  preference :rule_d1, :string
  preference :rule_d2, :string
  preference :rule_month, :string
  RULE_PREFERENCES = [
    "rule_quality_grade", "rule_photos", "rule_sounds",
    "rule_observed_on", "rule_d1", "rule_d2", "rule_month"
  ]
  
  SUBMISSION_BY_ANYONE = 'any'
  SUBMISSION_BY_CURATORS = 'curators'
  SUBMISSION_MODELS = [SUBMISSION_BY_ANYONE, SUBMISSION_BY_CURATORS]
  preference :submission_model, :string, default: SUBMISSION_BY_ANYONE

  MEMBERSHIP_OPEN = 'open'
  MEMBERSHIP_INVITE_ONLY = 'inviteonly'
  MEMBERSHIP_MODELS = [MEMBERSHIP_OPEN, MEMBERSHIP_INVITE_ONLY]
  preference :membership_model, :string, :default => MEMBERSHIP_OPEN

  NPS_BIOBLITZ_PROJECT_NAME = "2016 National Parks Bioblitz - NPS Servicewide"
  NPS_BIOBLITZ_GROUP_NAME = "2016 National Parks BioBlitz"

  accepts_nested_attributes_for :project_observation_fields, :allow_destroy => true
  accepts_nested_attributes_for :project_users, :allow_destroy => true

  validates_length_of :title, :within => 1..100
  validates_presence_of :user
  validates_format_of :event_url, :with => /\A#{URI.regexp}\z/,
    :message => "should look like a URL, e.g. #{Site.default.try(:url) || 'http://www.inaturalist.org'}",
    :allow_blank => true
  validates_presence_of :start_time, :if => lambda {|p| p.bioblitz? }, :message => "can't be blank for a bioblitz"
  validates_presence_of :end_time, :if => lambda {|p| p.bioblitz? }, :message => "can't be blank for a bioblitz"
  validate :place_with_boundary, :if => lambda {|p| p.bioblitz? }
  validate :one_year_time_span, :if => lambda {|p| p.bioblitz? }, :unless => "errors.any?"
  validate :aggregation_preference_allowed?

  def aggregation_preference_allowed?
    return if is_new_project?
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
  scope :featured_near_point, lambda {|latitude, longitude|
    latitude = latitude.to_f
    longitude = longitude.to_f
    featured.where("projects.latitude IS NULL OR ST_Distance(ST_Point(projects.longitude, projects.latitude), ST_Point(#{longitude}, #{latitude})) < 5").
    order("CASE WHEN projects.latitude IS NULL THEN 6 ELSE ST_Distance(ST_Point(projects.longitude, projects.latitude), ST_Point(#{longitude}, #{latitude})) END")
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

  if Rails.env.production?
    has_attached_file :icon,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      styles: { thumb: "48x48#", mini: "16x16#", span1: "30x30#", span2: "70x70#", original: "1024x1024>" },
      path: "projects/:id-icon-:style.:extension",
      url: ":s3_alias_url",
      default_url: "/attachment_defaults/general/:style.png"
    invalidate_cloudfront_caches :icon, "projects/:id-icon-*"
  else
    has_attached_file :icon,
      styles: { thumb: "48x48#", mini: "16x16#", span1: "30x30#", span2: "70x70#", original: "1024x1024>" },
      path: ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
      url: "/attachments/:class/:attachment/:id/:style/:basename.:extension",
      default_url: "/attachment_defaults/general/:style.png"
  end
  
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /gif/i, /octet-stream/], 
    :message => "must be JPG, PNG, or GIF"

  if Rails.env.production?
    has_attached_file :cover,
      storage: :s3,
      s3_credentials: "#{Rails.root}/config/s3.yml",
      s3_protocol: CONFIG.s3_protocol || "https",
      s3_host_alias: CONFIG.s3_host || CONFIG.s3_bucket,
      s3_region: CONFIG.s3_region,
      bucket: CONFIG.s3_bucket,
      path: "projects/:id-cover.:extension",
      url: ":s3_alias_url",
      default_url: ""
    invalidate_cloudfront_caches :cover, "projects/:id-cover.*"
  else
    has_attached_file :cover,
      :path => ":rails_root/public/attachments/:class/:id-cover.:extension",
      :url => "#{ CONFIG.s3_host }/attachments/:class/:id-cover.:extension",
      :default_url => ""
  end
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /octet-stream/], :message => "must be JPG or PNG"
  validate :cover_dimensions, unless: Proc.new { |p| p.errors.any? || p.is_new_project? }
  
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
    return if place_id.blank?
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

  def is_new_project?
    project_type === "umbrella" || project_type === "collection"
  end

  def preferred_start_date_or_time
    return unless start_time
    time = start_time.in_time_zone(user.time_zone)
    prefers_range_by_date? ? Date.parse(time.iso8601.split('T').first) : time
  end

  def preferred_end_date_or_time
    return unless end_time
    time = end_time.in_time_zone(user.time_zone)
    prefers_range_by_date? ? Date.parse(time.iso8601.split('T').first) : time
  end

  def strip_title
    self.title = title.strip
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

  def set_updated_at_if_preferences_changed
    if preferences.keys.any?{ |p| send("prefers_#{p}_changed?") }
      self.updated_at = Time.now
    end
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
    @rule_place ||= rule_places.first
  end

  def rule_places
    @rule_places ||= project_observation_rules.where(operator: "observed_in_place?").map(&:operand).compact
  end

  def rule_taxon
    @rule_taxon ||= rule_taxa.first
  end

  def rule_taxa
    @rule_taxa ||= project_observation_rules.where(operator: "in_taxon?").map(&:operand).compact
  end
  
  def icon_url
    return nil unless icon.file?
    icon.url( :span2 )
  end
  
  def project_observation_rule_terms
    project_observation_rules.map{|por| por.terms}.join('|')
  end

  def project_observations_count
    project_observations.count
  end

  def posts_count
    posts.count
  end
  
  def featured_at_utc
    featured_at.try(:utc)
  end

  def featured?
    !featured_at.blank?
  end

  def reset_last_aggregated_at
    if start_time_changed? || end_time_changed?
      self.last_aggregated_at = nil
    end
  end

  def remove_times_from_non_bioblitzes
    return if bioblitz? || is_new_project?
    self.start_time = nil
    self.end_time = nil
  end

  def tracking_code_allowed?(code)
    return false if code.blank?
    return false if tracking_codes.blank?
    tracking_codes.split(',').map{|c| c.strip}.include?(code)
  end

  def rule_place_ids
    rule_place_ids = project_observation_rules.select do |r|
      r.operator == "observed_in_place?"
    end.map( &:operand_id )
    [ place_id, rule_place_ids ].flatten.compact.uniq
  end

  def observations_url_params(options = {})
    params = { }
    if start_time && end_time
      if prefers_range_by_date?
        params.merge!(
          d1: preferred_start_date_or_time.to_s,
          d2: preferred_end_date_or_time.to_s
        )
      else
        params.merge!(
          d1: preferred_start_date_or_time.iso8601,
          d2: preferred_end_date_or_time.iso8601
        )
      end
    end
    taxon_ids = []
    place_ids = [ place_id ]
    project_observation_rules.each do |rule|
      case rule.operator
      when "in_taxon?"
        taxon_ids << rule.operand_id
      when "observed_in_place?"
        place_ids << rule.operand_id
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
      when "verifiable?"
        params[:verifiable] = true
      end
    end
    taxon_ids = taxon_ids.compact.uniq
    place_ids = place_ids.compact.uniq
    # the new obs search sets some defaults we want to override
    params[:verifiable] = "any" if !params[:verifiable]
    params[:place_id] = "any" if place_ids.blank?
    if !options[:extended] && taxon_ids.count + place_ids.count >= 50
      params = { apply_project_rules_for: self.id }
    else
      params.merge!(taxon_ids: taxon_ids) unless taxon_ids.blank?
      params.merge!(place_id: place_ids) unless place_ids.blank?
    end
    if options[:concat_ids]
      params[:taxon_ids] = params[:taxon_ids].join(",") if params[:taxon_ids].try(:class) == Array
      params[:place_id] = params[:place_id].join(",") if params[:place_id].try(:class) == Array
    end
    params
  end

  # TODO: probably merge most of this logic with observations_url_params
  def collection_search_parameters(options = {})
    params = { }
    if project_type == "umbrella"
      project_ids = []
      project_observation_rules.each do |rule|
        project_ids << rule.operand_id if rule.operator === "in_project?"
      end
      project_ids = project_ids.compact.uniq
      params.merge!(project_id: project_ids) unless project_ids.blank?
      return params
    end
    if start_time && end_time
      params[:d1] = preferred_start_date_or_time
      params[:d2] = preferred_end_date_or_time
    end
    taxon_ids = []
    user_ids = [ ]
    place_ids = [ place_id ]
    project_observation_rules.each do |rule|
      case rule.operator
      when "in_taxon?"
        taxon_ids << rule.operand_id
      when "observed_in_place?"
        place_ids << rule.operand_id
      when "has_a_photo?"
        params[:photos] = true
      when "has_a_sound?"
        params[:sounds] = true
      when "observed_by_user?"
        user_ids << rule.operand_id
      when "verifiable?"
        params[:quality_grade] = "research,needs_id"
      end
    end
    Project::RULE_PREFERENCES.each do |rule|
      rule_value = send( "prefers_#{rule}" )
      unless rule_value.nil? || rule_value == ""
        # map the rule values to their proper data types
        if [ "rule_d1", "rule_d2", "rule_observed_on" ].include?( rule )
          rule_value = rule_value.match( / / ) ? Time.parse( rule_value ) : Date.parse( rule_value )
        elsif rule_value.is_a?( String )
          is_int = rule_value.match( /^\d+ *(, *\d+)*$/ )
          rule_value = rule_value.split( "," ).map( &:strip )
          rule_value.map!( &:to_i ) if is_int
        end
        params[ rule.sub( "rule_", "" ) ] = rule_value
      end
    end
    taxon_ids = taxon_ids.compact.uniq
    place_ids = place_ids.compact.uniq
    user_ids = user_ids.compact.uniq
    params.merge!(taxon_id: taxon_ids) unless taxon_ids.blank?
    params.merge!(place_id: place_ids) unless place_ids.blank?
    params.merge!(user_id: user_ids) unless user_ids.blank?
    params
  end

  def can_be_converted_to_collection_project?
    return false if is_new_project?
    return false if collection_search_parameters.blank?
    return false if project_observation_rules.detect do |r|
      ![ "in_taxon?", "observed_in_place?", "has_a_photo?", "has_a_sound?",
         "observed_by_user?", "verifiable?" ].include?( r.operator )
    end
    true
  end

  def convert_properties_for_collection_project
    return unless can_be_converted_to_collection_project?
    return if is_new_project?
    self.prefers_rule_d1 = self.preferred_start_date_or_time if self.preferred_start_date_or_time
    self.prefers_rule_d2 = self.preferred_end_date_or_time if self.preferred_end_date_or_time
    if project_observation_rules.detect{ |r| r.operator == "verifiable?" }
      self.prefers_rule_quality_grade = "research,needs_id"
    end
    if place_id &&
      !project_observation_rules.detect{ |r| r.operator == "observed_in_place?" && r.operand_id == place_id}
      association(:project_observation_rules).add_to_target(ProjectObservationRule.new(
        ruler: self,
        operator: "observed_in_place?",
        operand_type: "Place",
        operand_id: place_id
      ))
    end
  end

  def convert_to_collection_project
    return unless can_be_converted_to_collection_project?
    return if is_new_project?
    convert_properties_for_collection_project
    self.prefers_aggregation = false
    self.project_type = "collection"
    save
  end

  def convert_collection_project_to_traditional_project
    return unless project_type == "collection"
    Project::RULE_PREFERENCES.each do |rule|
      self.send( "prefers_#{rule}=", nil )
    end
    self.project_type = (preferred_start_date_or_time || preferred_end_date_or_time) ? "bioblitz" : nil
    save
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
    if project_users.loaded?
      project_users.select{ |pu| pu.role == ProjectUser::MANAGER }.map(&:user)
    else
      users.where("project_users.role = ?", ProjectUser::MANAGER)
    end
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
    t = DateTime.parse( preferred_rule_d1 ) unless preferred_rule_d1.blank?
    t ||= start_time
    return nil if t.blank?
    if prefers_range_by_date?
      t.to_date <= Date.today
    else
      t < Time.now
    end
  end

  def event_ended?
    t = DateTime.parse( preferred_rule_d2 ) unless preferred_rule_d2.blank?
    t ||= end_time
    return nil if t.blank?
    if prefers_range_by_date?
      Date.today > t.to_date
    else
      Time.now > t
    end
  end

  def event_in_progress?
    unless preferred_rule_d1 && preferred_rule_d2
      return nil if end_time.blank? || start_time.blank? 
    end
    event_started? && !event_ended?
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
    # max_id prevents a problem with aggregated projects (see issue #1227)
    # Aggregated projects will add back whatever is currently relevant to the
    # project, but may as well remove all existing obs in case some don't match
    # the current rules. The max_id prevents this from deleting the re-aggregated
    # obs and creating an endless loop of deletes and re-agg
    max_id = Observation.maximum(:id)
    proj.project_observations.joins(:observation).
         where("observations.user_id = ?", usr).
         where("observations.id <= ?", max_id).find_each do |po|
      po.destroy
    end
  end

  def list_observed_and_total #denominator and numerator on project/show
    find_observed_and_total_for_project
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
  
  def find_observed_and_total_for_project
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
  
  def users_can_add?
    preferred_submission_model == SUBMISSION_BY_ANYONE
  end

  def aggregation_allowed?
    return false if is_new_project?
    return true if CONFIG.aggregator_exception_project_ids && CONFIG.aggregator_exception_project_ids.include?(id)
    return true if place && place.bbox_area.to_f < 141
    return true if project_observation_rules.where("operator IN (?)", %w(in_taxon? on_list?)).exists?
    return true if project_observation_rules.where("operator IN (?)", %w(observed_in_place?)).map{ |r|
      r.operand && r.operand.bbox_area < 141
    }.uniq == [ true ]
    false
  end

  def bioblitz?
    project_type == BIOBLITZ_TYPE
  end

  def update_counts
    update_users_observations_counts
    update_users_taxa_counts
  end

  def update_users_observations_counts(options = {})
    Project.transaction do
      # set all counts to zero
      project_users.update_all(observations_count: 0) unless options[:user_id]
      user_ids = options[:user_id] ? [ options[:user_id] ] :
        project_users.pluck(:user_id).uniq.sort
      user_ids.in_groups_of(500, false) do |uids|
        # matching the node.js iNaturalistAPI filters/aggregations for obs counts
        result = Observation.elastic_search(
          filters: [
            { term: { project_ids: self.id } },
            { terms: { "user.id": uids } }
          ],
          size: 0,
          aggregate: {
            top_observers: { terms: { field: "user.id", size: 100000 } } }
        )
        if result && result.response && result.response.aggregations
          result.response.aggregations.top_observers.buckets.each do |b|
            ProjectUser.where(project_id: id, user_id: b[:key]).
              update_all(observations_count: b.doc_count)
          end
        end
      end
    end
  end

  def update_users_taxa_counts(options = {})
    Project.transaction do
      # set all counts to zero
      project_users.update_all(taxa_count: 0) unless options[:user_id]
      user_ids = options[:user_id] ? [ options[:user_id] ] :
        project_users.pluck(:user_id).uniq.sort
      user_ids.in_groups_of(500, false) do |uids|
        # matching the node.js iNaturalistAPI filters/aggregations for species counts
        filters = [
          { term: { project_ids: self.id } },
          { range: { "taxon.rank_level": { lte: Taxon::SPECIES_LEVEL } } },
          { range: { "taxon.rank_level": { gte: Taxon::SUBSPECIES_LEVEL } } },
          { terms: { "user.id": uids } }
        ]
        result = Observation.elastic_search(
          filters: filters,
          size: 0,
          aggregate: {
            user_taxa: {
              terms: { field: "user.id", size: uids.length, order: { distinct_taxa: "desc" } },
              aggs: {
                distinct_taxa: {
                  cardinality: {
                    field: "taxon.min_species_ancestry", precision_threshold: 10000 } } } } }
        )
        if result && result.response && result.response.aggregations
          result.response.aggregations.user_taxa.buckets.each do |b|
            ProjectUser.where(project_id: id, user_id: b[:key]).
              update_all(taxa_count: b.distinct_taxa.value)
          end
        end
      end
    end
  end

  class ProjectAggregatorAlreadyRunning < StandardError; end

  def aggregate_observations(options = {})
    return false unless aggregation_allowed? && prefers_aggregation?
    logger = options[:logger] || Rails.logger
    start_time = Time.now
    added = 0
    fails = 0
    logger.info "[INFO #{Time.now}] Starting aggregation for #{self}"
    params = observations_url_params(extended: true).merge(per_page: 200, not_in_project: id)
    # making sure we only look at observations updated since the last aggregation
    unless last_aggregated_at.nil?
      params[:updated_since] = last_aggregated_at.to_s
      params[:aggregation_user_ids] = Preference.
        where(name: "project_addition_by").
        where(owner_type: "User").
        where("updated_at >= ?", last_aggregated_at).distinct.pluck(:owner_id)
      params[:aggregation_user_ids] += ProjectUser.
        where(project_id: id).
        where("updated_at >= ?", last_aggregated_at).distinct.pluck(:user_id)
      params[:aggregation_user_ids].uniq!
    end
    list = params[:list_id] ? List.find_by_id(params[:list_id]) : nil
    page = 1
    total_entries = nil
    last_observation_id = 0
    search_params = Observation.get_search_params(params)
    while true
      # stop if the project was deleted since the job started
      return unless Project.where(id: id).exists?
      search_params.merge!({ min_id: last_observation_id + 1,
        order_by: "id", order: "asc" })
      observations = Observation.page_of_results(search_params)
      break if observations.blank?
      total_entries = observations.total_entries if page === 1
      Rails.logger.debug "[DEBUG] Processing page #{observations.current_page} of #{observations.total_pages} for #{slug}"
      observations.each do |o|
        # don't use first_or_create here
        po = transaction do
          ProjectObservation.where(project: self, observation: o).first ||
            ProjectObservation.create(project: self, observation: o)
        end
        if po && !po.errors.any?
          added += 1
        else
          fails += 1
          Rails.logger.debug "[DEBUG] Failed to add #{po} to #{self}: #{po.errors.full_messages.to_sentence}"
        end
      end
      last_observation_id = observations.last.id
      observations = nil
      page += 1
    end
    update_counts
    update_attributes(last_aggregated_at: Time.now)
    logger.info "[INFO #{Time.now}] Finished aggregation for #{self} in #{Time.now - start_time}s, #{added} observations added, #{fails} failures"
  end

  def self.aggregate_observations_for(project_id)
    return unless project = Project.find_by_id(project_id)
    project.aggregate_observations
  end

  def self.queue_project_aggregations(options = {})
    Project.joins(:stored_preferences).where("preferences.name = 'aggregation' AND preferences.value = 't'").find_each do |p|
      next unless p.aggregation_allowed? && p.prefers_aggregation?
      Project.delay(priority: INTEGRITY_PRIORITY, queue: "slow",
        unique_hash: { "Project::aggregate_observations_for": p.id }).aggregate_observations_for( p.id )
    end
  end

  def sane_destroy
    project_observations.delete_all
    posts.select("id, parent_type, parent_id, user_id").find_each(&:destroy)
    destroy
  end

  def node_api_species_count
    response = INatAPIService.observations_species_counts(
      project_id: self.id, per_page: 0, ttl: 300)
    (response && response.total_results) || 0
  end

  def self.recently_added_to_ids( options = { } )
    options[:limit] ||= 9
    project_observations = ProjectObservation.select( "project_id" )
    # add place filter
    if options[:place] && options[:place].is_a?( Place )
      project_observations = project_observations.
        joins( project: :place ).
        where( options[:place].self_and_descendant_conditions )
    end
    # ignore projects previously included
    if options[:not_project_ids]
      project_observations = project_observations.
        where("project_observations.project_id NOT IN (?)", options[:not_project_ids] )
    end
    ids = project_observations.
      order( "project_observations.id DESC" ).
      limit( options[:limit] ).
      pluck(:project_id).uniq
    # there are no more recent projects
    return if ids.empty?
    # if there might be more results, and we are short of the requested limit
    if ids.length < options[:limit]
      # fetch the remaining projects
      ignore_project_ids = options[:not_project_ids] ? options[:not_project_ids].dup : []
      more_ids = Project.recently_added_to_ids( options.merge(
        limit: options[:limit] - ids.length,
        not_project_ids: ids + ignore_project_ids ) )
      ids += more_ids if more_ids
    end
    ids
  end

  def self.recently_added_to( options = { } )
    Project.where( id: Project.recently_added_to_ids( options ) ).not_flagged_as_spam
  end

  def self.refresh_es_index
    Project.__elasticsearch__.refresh_index! unless Rails.env.test?
  end

end

class Project < ActiveRecord::Base
  belongs_to :user
  belongs_to :place, :inverse_of => :projects
  has_many :project_users, :dependent => :delete_all
  has_many :project_observations, :dependent => :destroy
  has_many :project_invitations, :dependent => :destroy
  has_many :users, :through => :project_users
  has_many :observations, :through => :project_observations
  has_one :project_list, :dependent => :destroy
  has_many :listed_taxa, :through => :project_list
  has_many :taxa, :through => :listed_taxa
  has_many :project_assets, :dependent => :destroy
  has_one :custom_project, :dependent => :destroy
  has_many :project_observation_fields, :dependent => :destroy, :inverse_of => :project, :order => "position"
  has_many :observation_fields, :through => :project_observation_fields
  has_many :posts, :as => :parent, :dependent => :destroy
  has_many :assessments, :dependent => :destroy
    
  before_save :strip_title
  after_create :create_the_project_list
  after_save :add_owner_as_project_user
  
  has_rules_for :project_users, :rule_class => ProjectUserRule
  has_rules_for :project_observations, :rule_class => ProjectObservationRule

  has_subscribers :to => {
    :posts => {:notification => "created_project_post"},
    :project_users => {:notification => "curator_change"}
  }

  extend FriendlyId
  friendly_id :title, :use => :history, :reserved_words => ProjectsController.action_methods.to_a
  
  preference :count_from_list, :boolean, :default => false
  preference :place_boundary_visible, :boolean, :default => false
  
  # For some reason these don't work here
  # accepts_nested_attributes_for :project_user_rules, :allow_destroy => true
  # accepts_nested_attributes_for :project_observation_rules, :allow_destroy => true
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
  
  scope :featured, where("featured_at IS NOT NULL")
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
      conditions = place.descendant_conditions
      conditions[0] += " OR places.id = ?"
      conditions << place
      joins(:place).where(conditions)
    else
      where("1 = 2")
    end
  }
  
  has_attached_file :icon, 
    :styles => { :thumb => "48x48#", :mini => "16x16#", :span1 => "30x30#", :span2 => "70x70#" },
    :path => ":rails_root/public/attachments/:class/:attachment/:id/:style/:basename.:extension",
    :url => "/attachments/:class/:attachment/:id/:style/:basename.:extension",
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
      :url => "/attachments/:class/:id-cover.:extension",
      :default_url => ""
  end
  validates_attachment_content_type :icon, :content_type => [/jpe?g/i, /png/i, /octet-stream/], :message => "must be JPG or PNG"
  validate :cover_dimensions, :unless => "errors.any?"
  
  CONTEST_TYPE = 'contest'
  OBS_CONTEST_TYPE = 'observation contest'
  ASSESSMENT_TYPE = 'assessment'
  BIOBLITZ_TYPE = 'bioblitz'
  PROJECT_TYPES = [CONTEST_TYPE, OBS_CONTEST_TYPE , ASSESSMENT_TYPE, BIOBLITZ_TYPE]
  RESERVED_TITLES = ProjectsController.action_methods
  MAP_TYPES = %w(roadmap terrain satellite hybrid)
  validates_exclusion_of :title, :in => RESERVED_TITLES + %w(user)
  validates_uniqueness_of :title
  validates_inclusion_of :map_type, :in => MAP_TYPES

  define_index do
    indexes :title
    indexes :description
    set_property :delta => :delayed
  end

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
  
  def strip_title
    self.title = title.strip
    true
  end

  def cover_dimensions
    return true unless cover.queued_for_write[:original]
    dimensions = Paperclip::Geometry.from_file(cover.queued_for_write[:original].path)
    if dimensions.width != 950 || dimensions.height > 400
      errors.add(:cover, 'image must be exactly 950px wide and at most 400px tall')
    end
  end
  
  def add_owner_as_project_user
    return true unless user_id_changed?
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
  
  def contest?
     [CONTEST_TYPE, OBS_CONTEST_TYPE].include?(project_type)
  end
  
  def editable_by?(user)
    return false if user.blank?
    return true if user.id == user_id || user.is_admin?
    pu = user.project_users.first(:conditions => {:project_id => id})
    pu && pu.is_manager?
  end
  
  def curated_by?(user)
    return false if user.blank?
    return true if user.is_admin?
    project_users.curators.exists?(:user_id => user.id) || project_users.managers.exists?(:user_id => user.id)
  end
  
  def rule_place
    project_observation_rules.first(:conditions => {:operator => "observed_in_place?"}).try(:operand)
  end

  def rule_taxon
    @rule_taxon ||= project_observation_rules.where(:operator => "in_taxon?").first.try(:operand)
  end
  
  def icon_url
    icon.file? ? "#{CONFIG.site_url}#{icon.url(:span2)}" : nil
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
    scope = Observation.scoped
    project_observation_rules.each do |rule|
      case rule.operator
      when "in_taxon?"
        scope = scope.of(rule.operand)
      when "observed_in_place?"
        scope = scope.in_place(rule.operand)
      when "on_list?"
        scope = scope.scoped(
          :joins => "JOIN listed_taxa ON listed_taxa.list_id = #{project_list.id}", 
          :conditions => "observations.taxon_id = listed_taxa.taxon_id")
      when "identified?"
        scope = scope.scoped(:conditions => "observations.taxon_id IS NOT NULL")
      when "georeferenced"
        scope = scope.scoped(:conditions => "observations.geom IS NOT NULL")
      end
    end
    scope
  end

  def cached_slug
    slug
  end

  def curators
    users.where("project_users.role = ?", ProjectUser::CURATOR).scoped
  end

  def managers
    users.where("project_users.role = ?", ProjectUser::MANAGER).scoped
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

  def generate_csv(path, columns)
    project_columns = %w(curator_ident_taxon_id curator_ident_taxon_name curator_ident_user_id curator_ident_user_login tracking_code)
    columns += project_columns
    ofv_columns = self.observation_fields.map{|of| "field:#{of.normalized_name}"}
    columns += ofv_columns
    CSV.open(path, 'w') do |csv|
      csv << columns
      self.project_observations.includes(:observation => [:taxon, {:observation_field_values => :observation_field}]).find_each do |project_observation|
        csv << columns.map {|column| project_observation.to_csv_column(column, :project => self)}
      end
    end
  end

  def eventbrite_id
    return if event_url.blank?
    return unless event_url =~ /eventbrite\.com/
    @eventbrite_id ||= URI.parse(event_url).path.split('/').last[/\d+/, 0]
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
    project.project_observations.find_each(
        :include => {:observation => :identifications}, 
        :conditions => [
          "project_observations.curator_identification_id IS NULL AND identifications.user_id = ?", 
          project_user.user_id]) do |po|
      curator_ident = po.observation.identifications.detect{|ident| ident.user_id == project_user.user_id}
      po.update_attributes(:curator_identification => curator_ident)
      ProjectUser.delay.update_observations_counter_cache_from_project_and_user(project_id, po.observation.user_id)
      ProjectUser.delay.update_taxa_counter_cache_from_project_and_user(project_id, po.observation.user_id)
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
    
    project_curators = project.project_users.all(:conditions => ["role IN (?)", [ProjectUser::MANAGER, ProjectUser::CURATOR]])
    project_curator_user_ids = project_curators.map{|pu| pu.user_id}
    
    project.project_observations.find_each(find_options) do |po|
      curator_ident = po.observation.identifications.detect{|ident| project_curator_user_ids.include?(ident.user_id)}
      po.update_attributes(:curator_identification => curator_ident)
      ProjectUser.delay.update_observations_counter_cache_from_project_and_user(project_id, po.observation.user_id)
      ProjectUser.delay.update_taxa_counter_cache_from_project_and_user(project_id, po.observation.user_id)
    end
  end
  
  def self.refresh_project_list(project, options = {})
    unless project.is_a?(Project)
      project = Project.find_by_id(project, :include => :project_list)
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
    observed_taxa_count = project.project_list.listed_taxa.count(:conditions => "last_observation_id IS NOT NULL")
    project.update_attributes(:observed_taxa_count => observed_taxa_count)
  end
  
  
  def self.delete_project_observations_on_leave_project(project_id, user_id)
    unless proj = Project.find_by_id(project_id)
      return
    end
    unless usr = User.find_by_id(user_id)
      return
    end
    proj.project_observations.find_each(:include => :observation, :conditions => ["observations.user_id = ?", usr]) do |po|
      po.destroy
    end
  end
end

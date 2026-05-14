# frozen_string_literal: true

class Announcement < ApplicationRecord
  PLACEMENTS = %w(
    users/dashboard#sidebar
    users/dashboard
    welcome/index
    mobile/home
  ).freeze
  PARAM_PLACEMENTS = PLACEMENTS + %w(mobile)

  PLACEMENTS.each do | placement |
    const_set placement.parameterize.underscore.upcase, placement
  end

  DISMISSIBLE_PLACEMENTS = [
    MOBILE_HOME,
    USERS_DASHBOARD,
    USERS_DASHBOARD_SIDEBAR
  ].freeze

  INAT_IOS = "inat-ios"
  INAT_ANDROID = "inat-android"
  SEEK = "seek"
  INATRN = "inatrn"

  CLIENTS = {
    MOBILE_HOME => [
      INAT_IOS,
      INAT_ANDROID,
      SEEK,
      INATRN
    ]
  }.freeze

  TARGET_GROUPS = {
    "user_id_parity" => %w(
      even
      odd
    ),
    "created_second_parity" => %w(
      even
      odd
    ),
    "user_id_digit_sum_parity" => %w(
      even
      odd
    )
  }.freeze

  YES = "yes"
  NO = "no"
  ANY = "any"
  YES_NO_ANY = [YES, NO, ANY].freeze

  belongs_to :user
  belongs_to :parent_announcement, class_name: "Announcement", optional: true
  has_and_belongs_to_many :sites
  has_many :announcement_impressions, dependent: :delete_all
  has_many :child_announcements, class_name: "Announcement", foreign_key: :parent_announcement_id, dependent: :nullify

  validates_presence_of :placement, :start, :end, :body
  validate :valid_placement_clients
  validate :parent_announcement_cannot_be_self
  validate :parent_announcement_cannot_have_parent
  validates_inclusion_of :target_group_type, in: TARGET_GROUPS.keys, if: :target_group_type?
  validates_inclusion_of :target_logged_in, in: YES_NO_ANY
  validates_inclusion_of :target_curators, in: YES_NO_ANY
  validates_inclusion_of :target_project_admins, in: YES_NO_ANY
  validates_presence_of :target_group_partition, if: :target_group_type?
  validate :valid_target_group_partition, if: :target_group_type?
  validates :min_identifications,
    allow_nil: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_identifications,
    allow_nil: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :min_observations,
    allow_nil: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_observations,
    allow_nil: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  preference :target_staff, :boolean
  preference :target_unconfirmed_users, :boolean
  preference :exclude_monthly_supporters, :boolean

  scope :in_locale, lambda {| locale |
    where( "(? = ANY (locales)) OR locales IS NULL OR locales = '{}'", locale )
  }

  scope :in_specific_locale, lambda {| locale |
    where( "? = ANY (locales)", locale )
  }

  before_save :clean_target_group
  before_save :reset_options_requiring_login
  before_validation :compact_array_attributes

  after_save :sync_announcement_dismissals

  def valid_placement_clients
    if clients.any? do | client |
      !Announcement::CLIENTS[placement] || !Announcement::CLIENTS[placement].include?( client )
    end
      errors.add( :clients, :must_be_valid_for_specified_placement )
    end
  end

  def valid_target_group_partition
    return if Announcement::TARGET_GROUPS[target_group_type]&.include?( target_group_partition )

    errors.add( :target_group_partition, :must_be_valid_for_specified_target_group )
  end

  def parent_announcement_cannot_be_self
    return unless parent_announcement_id.present? && parent_announcement_id == id

    errors.add( :parent_announcement_id, "cannot reference itself" )
  end

  def parent_announcement_cannot_have_parent
    return unless parent_announcement_id.present?
    return unless parent_announcement&.parent_announcement_id.present?

    errors.add( :parent_announcement_id, "cannot be a child announcement (only one level of nesting allowed)" )
  end

  def session_key
    "user-seen-ann-#{id}"
  end

  def body_preview( length = 60 )
    ActionController::Base.helpers.strip_tags( body ).to_s.truncate( length )
  end

  def dropdown_label
    locale_label = locales.presence&.join( ", " ) || "all locales"
    "##{id} - #{body_preview} (#{locale_label})"
  end

  def compact_array_attributes
    array_attributes = %w(
      clients
      locales
      ip_countries
      exclude_ip_countries
      include_observation_oauth_application_ids
      exclude_observation_oauth_application_ids
      include_virtuous_tags
      exclude_virtuous_tags
    )
    array_attributes.each do | attr |
      send( "#{attr}=", ( send( attr ) || [] ).reject( &:blank? ).compact )
    end
    nil
  end

  def visible_in_country?( country )
    includes = ip_countries || []
    excludes = exclude_ip_countries || []
    if includes.present?
      ( includes - excludes ).include?( country )
    else
      !excludes.include?( country )
    end
  end

  def clean_target_group
    self.target_group_type = nil if target_group_type.blank?
    self.target_group_partition = nil if target_group_type.nil?
  end

  def reset_options_requiring_login
    return if target_logged_in == YES

    self.user_created_start_date = nil
    self.user_created_end_date = nil
    self.include_donor_start_date = nil
    self.include_donor_end_date = nil
    self.exclude_donor_start_date = nil
    self.exclude_donor_end_date = nil
    self.prefers_exclude_monthly_supporters = false
    self.min_observations = nil
    self.max_observations = nil
    self.last_observation_start_date = nil
    self.last_observation_end_date = nil
    self.include_observation_oauth_application_ids = []
    self.exclude_observation_oauth_application_ids = []
    self.include_virtuous_tags = []
    self.exclude_virtuous_tags = []
    self.min_identifications = nil
    self.max_identifications = nil
    self.user_created_start_date = nil
    self.user_created_end_date = nil
    self.prefers_target_unconfirmed_users = false
    self.target_curators = ANY
    self.target_project_admins = ANY
    self.target_group_type = nil
    self.target_group_partition = nil
  end

  def dismissed_by?( user )
    return false unless dismissible?

    user_id = user.id if user.is_a?( User )
    user_id = user_id.to_i
    dismiss_user_ids.include?( user_id )
  end

  def impressions_count
    announcement_impressions.sum( :impressions_count )
  end

  def dismissals_count
    dismiss_user_ids.count
  end

  # This works by excluding users from filters, so it should only return false
  # until the very end, otherwise you'll block subsequent filters from being
  # checked
  def targeted_to_user?( user )
    return false if prefers_target_staff && ( user.blank? || !user.is_admin? )
    return false if target_creator && ( user.blank? || user.id != user_id )
    return false if user&.monthly_donor? && prefers_exclude_monthly_supporters
    return false if target_group_type && user.blank?
    return false if target_logged_in == YES && user.blank?
    return false if target_logged_in == NO && user

    if min_identifications && ( !user || user.identifications_count < min_identifications )
      return false
    end

    if max_identifications && ( user&.identifications_count || 0 ) > max_identifications
      return false
    end

    if min_observations && ( !user || user.observations_count < min_observations )
      return false
    end

    if max_observations && ( user&.observations_count || 0 ) > max_observations
      return false
    end

    case target_group_type
    when "user_id_parity"
      case target_group_partition
      when "even"
        return false if user.id.odd?
      when "odd"
        return false if user.id.even?
      end
    when "created_second_parity"
      case target_group_partition
      when "even"
        return false if user.created_at.to_i.odd?
      when "odd"
        return false if user.created_at.to_i.even?
      end
    when "user_id_digit_sum_parity"
      case target_group_partition
      when "even"
        return false if user.id.digits.sum.odd?
      when "odd"
        return false if user.id.digits.sum.even?
      end
    end

    return false if target_curators == YES && !user&.is_curator?
    return false if target_curators == NO && user&.is_curator?

    return false if target_project_admins == YES && !user&.projects&.any?
    return false if target_project_admins == NO && user&.projects&.any?

    return false if ( include_donor_start_date || include_donor_end_date ) && (
      !user || user.user_donations.
        where( "donated_at >= ?", include_donor_start_date || Date.new( 2018, 1, 1 ) ).
        where( "donated_at <= ?", include_donor_end_date || Time.now ).none?
    )

    return false if ( exclude_donor_start_date || exclude_donor_end_date ) &&
      user && user.user_donations.
        where( "donated_at >= ?", exclude_donor_start_date || Date.new( 2018, 1, 1 ) ).
        where( "donated_at <= ?", exclude_donor_end_date || Time.now ).any?

    if user_created_start_date
      return false unless user
      return false if user.created_at < user_created_start_date
    end

    if user_created_end_date
      return false unless user
      return false if user.created_at > user_created_end_date
    end

    return false if prefers_target_unconfirmed_users && user&.confirmed?

    if user && ( last_observation_start_date || last_observation_end_date )
      last_observation_created_at = user.last_observation_created_at
      # if the user has never created an observation, don't show the announcement
      return false unless last_observation_created_at
      # if the user has created an observation, but it's outside the date range, don't show
      return false if last_observation_start_date && last_observation_created_at < last_observation_start_date
      return false if last_observation_end_date && last_observation_created_at > last_observation_end_date
    end

    # If we're including obs apps, look for any obs the user has created with those apps
    if user && !include_observation_oauth_application_ids.blank?
      num_obs_from_included_apps = Observation.elastic_search(
        filters: [
          { term: { "user.id" => user.id } },
          { terms: { oauth_application_id: include_observation_oauth_application_ids } }
        ],
        size: 0
      ).total_entries
      return false if num_obs_from_included_apps.zero?
    end

    # If we're excluding obs apps, look for any obs the user has created with those apps
    if user && !exclude_observation_oauth_application_ids.blank?
      num_obs_from_excluded_apps = Observation.elastic_search(
        filters: [
          { term: { "user.id" => user.id } },
          { terms: { oauth_application_id: exclude_observation_oauth_application_ids } }
        ],
        size: 0
      ).total_entries
      return false if num_obs_from_excluded_apps.positive?
    end

    return false if user && !include_virtuous_tags.blank? &&
      !user.user_virtuous_tags.map( &:virtuous_tag ).intersect?( include_virtuous_tags )

    return false if user && !exclude_virtuous_tags.blank? &&
      user.user_virtuous_tags.map( &:virtuous_tag ).intersect?( exclude_virtuous_tags )

    true
  end

  def sync_announcement_dismissals
    return unless saved_change_to_dismiss_user_ids

    previous_values, new_values = saved_change_to_dismiss_user_ids
    newly_dismissed_user_ids = new_values - previous_values
    newly_dismissed_user_ids.each do | newly_dismissed_user_id |
      AnnouncementDismissal.create(
        announcement: self,
        user_id: newly_dismissed_user_id
      )
    end

    dismiss_user_ids_removed = previous_values - new_values
    dismiss_user_ids_removed.each do | dismiss_user_id_removed |
      AnnouncementDismissal.where(
        announcement: self,
        user_id: dismiss_user_id_removed
      ).destroy_all
    end
  end

  def self.active( options = {} )
    site = options[:site]
    user = options[:user]
    scope = Announcement.
      includes( :sites ).
      where( '? BETWEEN "start" AND "end"', Time.now.utc ).
      limit( 50 )
    placements = options[:placement].to_s.split( "," ) & PARAM_PLACEMENTS
    if placements.size.positive?
      scope = if placements.include?( "mobile" )
        scope.where( "placement LIKE 'mobile%' OR placement IN (?)", placements )
      else
        scope.where( placement: placements )
      end
    end
    if CLIENTS.values.flatten.include?( options[:client] )
      scope = scope.where( "? = ANY( clients ) OR clients = '{}'", options[:client] )
    end
    if options[:user_agent_client]
      scope = scope.where( "? = ANY( clients ) OR clients = '{}'", options[:user_agent_client] )
    end

    all_announcements = scope.to_a
    locale_str = I18n.locale.to_s
    lang_only = locale_str.split( "-" ).first

    geoip_country = if options[:ip]
      INatAPIService.geoip_lookup( { ip: options[:ip] } )&.results&.country
    end

    families = all_announcements.group_by {| a | a.parent_announcement_id || a.id }

    announcements = families.flat_map do | _key, group |
      filtered = group.select {| a | a.targeted_to_user?( user ) && !a.dismissed_by?( user ) }

      if options[:ip]
        filtered = if geoip_country.present?
          filtered.select {| a | a.visible_in_country?( geoip_country ) }
        else
          filtered.select {| a | a.ip_countries.blank? }
        end
      end

      filtered = if site
        filtered.select {| a | a.site_ids.blank? || a.site_ids.include?( site.id ) }
      else
        filtered.select {| a | a.site_ids.blank? }
      end

      filtered = pick_best_locale_matches( filtered, locale_str, lang_only )

      filtered
    end

    # TODO: remove excludes_non_site logic once the column is fully deprecated.
    # This was a workaround now replaced by parent_announcement_id family grouping.
    if announcements.detect {| a | a.site_ids.present? && a.excludes_non_site }
      announcements = announcements.select {| a | a.site_ids.present? }
    end

    announcements.sort_by do | a |
      [
        a.locales.include?( I18n.locale.to_s ) ? 0 : 1,
        a.id * -1
      ]
    end
  end

  def self.pick_best_locale_matches( group, locale_str, lang_only )
    exact = group.select {| a | a.locales&.include?( locale_str ) }
    return exact if exact.any?

    if locale_str != lang_only
      lang = group.select {| a | a.locales&.include?( lang_only ) }
      return lang if lang.any?
    end

    no_locale = group.select {| a | a.locales.blank? }
    return no_locale if no_locale.any?

    []
  end
  private_class_method :pick_best_locale_matches

  def self.active_in_placement( placement, options = {} )
    active( options.merge( placement: placement ) )
  end

  def serializable_hash( opts = {} )
    options = opts.clone
    options[:methods] ||= []
    options[:only] ||= []
    options[:only] += [
      :body,
      :clients,
      :dismissible,
      :end,
      :id,
      :locales,
      :parent_announcement_id,
      :placement,
      :start
    ]
    if options[:except]
      options[:methods] = options[:methods] - options[:except]
    end
    options[:methods].uniq!
    options[:only].uniq!
    super( options )
  end

  def duplicate_as_user( duplicate_user )
    announcement = deep_dup

    announcement.dismiss_user_ids = []
    announcement.user = duplicate_user
    announcement.sites = sites
    announcement.stored_preferences = stored_preferences
    announcement.parent_announcement_id = parent_announcement_id || id

    announcement
  end
end

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
  has_and_belongs_to_many :sites
  has_many :announcement_impressions, dependent: :delete_all
  validates_presence_of :placement, :start, :end, :body
  validate :valid_placement_clients
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

  def session_key
    "user-seen-ann-#{id}"
  end

  def compact_array_attributes
    self.clients = ( clients || [] ).reject( &:blank? ).compact
    self.locales = ( locales || [] ).reject( &:blank? ).compact
    self.ip_countries = ( ip_countries || [] ).reject( &:blank? ).compact
    self.include_observation_oauth_application_ids = ( include_observation_oauth_application_ids || [] ).
      reject( &:blank? ).compact
    self.exclude_observation_oauth_application_ids = ( exclude_observation_oauth_application_ids || [] ).
      reject( &:blank? ).compact
  end

  def clean_target_group
    self.target_group_type = nil if target_group_type.blank?
    self.target_group_partition = nil if target_group_type.nil?
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

    return false if user && user_created_start_date && user.created_at < user_created_start_date
    return false if user && user_created_end_date && user.created_at > user_created_end_date

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
      where( '? BETWEEN "start" AND "end"', Time.now.utc ).
      joins( "LEFT OUTER JOIN announcements_sites ON announcements_sites.announcement_id = announcements.id" ).
      joins( "LEFT OUTER JOIN sites ON sites.id = announcements_sites.site_id" ).
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

    # Site filtering
    scope = if site
      scope.
        where(
          "announcements_sites.site_id IS NULL OR announcements_sites.site_id = ?",
          site || Site.default
        )
    else
      # unauthenticated requests exclude announcements associated with sites
      scope.where( "announcements_sites.site_id IS NULL" )
    end
    base_scope = scope
    announcements = scope.in_specific_locale( I18n.locale )
    announcements = scope.in_specific_locale( I18n.locale.to_s.split( "-" ).first ) if announcements.blank?
    announcements = scope.in_locale( I18n.locale ) if announcements.blank?
    announcements = scope.in_locale( I18n.locale.to_s.split( "-" ).first ) if announcements.blank?
    if announcements.blank?
      announcements = base_scope.in_specific_locale( I18n.locale ).where( "sites.id IS NULL" )
      announcements = base_scope.where( "sites.id IS NULL AND locales IS NULL" ) if announcements.blank?
      announcements = announcements.to_a.flatten
    end
    if announcements.blank?
      announcements = base_scope.where( "(locales IS NULL OR locales = '{}') AND sites.id IS NULL" )
    end

    announcements = announcements.select do | a |
      a.targeted_to_user?( user ) && !a.dismissed_by?( user )
    end

    # Locale- and site- specific targeting above may have excluded
    # announcements without those filters, so we need to add them back in and
    # check their targeting. This is kind of a pointless extra db query. We
    # might just want to do locale and site filtering in Ruby instead of the
    # DB for simplicity.
    if announcements.blank?
      announcements = base_scope.where( "(locales IS NULL OR locales = '{}') AND sites.id IS NULL" ).select do | a |
        a.targeted_to_user?( user ) && !a.dismissed_by?( user )
      end
    end

    if options[:ip]
      geoip_country = INatAPIService.geoip_lookup( { ip: options[:ip] } )&.results&.country
      announcements = announcements.select {| a | a.ip_countries.blank? || a.ip_countries.include?( geoip_country ) }
    end

    # Remove non-site announcements if some announcements target sites
    announcement_target_site = announcements.detect do | annc |
      annc.site_ids.present? && annc.excludes_non_site
    end
    if announcement_target_site
      announcements = announcements.select do | annc |
        annc.site_ids.present?
      end
    end

    announcements.sort_by do | a |
      [
        a.locales.include?( I18n.locale ) ? 0 : 1,
        a.id * -1
      ]
    end
  end

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
end

# frozen_string_literal: true

class Announcement < ApplicationRecord
  PLACEMENTS = %w(
    users/dashboard#sidebar
    users/dashboard
    welcome/index
    mobile/home
  ).freeze

  CLIENTS = {
    "mobile/home" => %w(
      inat-ios
      inat-android
      seek
      inatrn
    )
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

  has_and_belongs_to_many :sites
  validates_presence_of :placement, :start, :end, :body
  validate :valid_placement_clients
  validates_inclusion_of :target_group_type, in: TARGET_GROUPS.keys, if: :target_group_type?
  validates_presence_of :target_group_partition, if: :target_group_type?
  validate :valid_target_group_partition, if: :target_group_type?

  preference :target_staff, :boolean
  preference :target_unconfirmed_users, :boolean
  preference :exclude_monthly_supporters, :boolean

  scope :in_locale, lambda {| locale |
    where( "(? = ANY (locales)) OR locales IS NULL OR locales = '{}'", locale )
  }

  scope :in_specific_locale, lambda {| locale |
    where( "? = ANY (locales)", locale )
  }

  before_save :compact_locales
  before_save :clean_target_group
  before_validation :compact_clients

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

  def compact_locales
    self.locales = ( locales || [] ).reject( &:blank? ).compact
  end

  def compact_clients
    self.clients = ( clients || [] ).reject( &:blank? ).compact
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

  def targeted_to_user?( user )
    return false if prefers_target_staff && ( user.blank? || !user.is_admin? )
    return false if user&.monthly_donor? && prefers_exclude_monthly_supporters
    return false if target_group_type && user.blank?

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

    return false if ( include_donor_start_date || include_donor_end_date ) && (
      !user || user.user_donations.
        where( "donated_at >= ?", include_donor_start_date || Date.new( 2018, 1, 1 ) ).
        where( "donated_at <= ?", include_donor_end_date || Time.now ).none?
    )

    return false if ( exclude_donor_start_date || exclude_donor_end_date ) &&
      user && user.user_donations.
        where( "donated_at >= ?", exclude_donor_start_date || Date.new( 2018, 1, 1 ) ).
        where( "donated_at <= ?", exclude_donor_end_date || Time.now ).any?

    if prefers_target_unconfirmed_users
      return user && !user.confirmed?
    end

    true
  end

  def self.active_in_placement( placement, site )
    scope = Announcement.
      joins( "LEFT OUTER JOIN announcements_sites ON announcements_sites.announcement_id = announcements.id" ).
      joins( "LEFT OUTER JOIN sites ON sites.id = announcements_sites.site_id" ).
      where( 'placement = ? AND ? BETWEEN "start" AND "end"', placement, Time.now.utc ).
      limit( 50 )
    base_scope = scope
    scope = scope.where( "sites.id = ?", site.id )
    @announcements = scope.in_specific_locale( I18n.locale )
    @announcements = scope.in_specific_locale( I18n.locale.to_s.split( "-" ).first ) if @announcements.blank?
    @announcements = scope.in_locale( I18n.locale ) if @announcements.blank?
    @announcements = scope.in_locale( I18n.locale.to_s.split( "-" ).first ) if @announcements.blank?
    if @announcements.blank?
      @announcements = base_scope.in_specific_locale( I18n.locale ).where( "sites.id IS NULL" )
      @announcements = base_scope.where( "sites.id IS NULL AND locales IS NULL" ) if @announcements.blank?
      @announcements = @announcements.to_a.flatten
    end
    if @announcements.blank?
      @announcements = base_scope.where( "(locales IS NULL OR locales = '{}') AND sites.id IS NULL" )
    end
    @announcements = @announcements.sort_by do | a |
      [
        a.site_ids.include?( @site.try( :id ) ) ? 0 : 1,
        a.locales.include?( I18n.locale ) ? 0 : 1,
        a.id * -1
      ]
    end
  end
end

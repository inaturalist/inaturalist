# frozen_string_literal: true

class Announcement < ApplicationRecord
  PLACEMENTS = %w(
    users/dashboard#sidebar
    users/dashboard
    welcome/index
    mobile/home
  ).freeze
  has_and_belongs_to_many :sites
  validates_presence_of :placement, :start, :end, :body

  preference :target_staff, :boolean
  preference :target_unconfirmed_users, :boolean

  scope :in_locale, lambda {| locale |
    where( "(? = ANY (locales)) OR locales IS NULL OR locales = '{}'", locale )
  }

  scope :in_specific_locale, lambda {| locale |
    where( "? = ANY (locales)", locale )
  }

  before_save :compact_locales

  def session_key
    "user-seen-ann-#{id}"
  end

  def compact_locales
    self.locales = ( locales || [] ).reject( &:blank? ).compact
  end

  def dismissed_by?( user )
    return false unless dismissible?

    user_id = user.id if user.is_a?( User )
    user_id = user_id.to_i
    dismiss_user_ids.include?( user_id )
  end

  def targeted_to_user?( user )
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

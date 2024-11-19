# frozen_string_literal: true

class AnnouncementImpression < ApplicationRecord
  belongs_to :announcement
  belongs_to :user

  validates_uniqueness_of :user_id, scope: [:announcement_id, :platform_type],
    if: -> { user_id.present? }
  validates_uniqueness_of :request_ip, scope: [:announcement_id, :platform_type],
    unless: -> { user_id.present? }

  def self.increment_for_announcement( announcement, options = {} )
    return unless announcement.is_a?( Announcement )
    return unless options[:user_id] || options[:user] || options[:request_ip]

    base_impression_options = {
      announcement_id: announcement.id,
      platform_type: options[:platform_type] == "mobile" ? "mobile" : "web"
    }

    if options[:user_id] || options[:user]
      user_impression_options = base_impression_options.merge( user: options[:user_id] || options[:user] )
      existing_impression = AnnouncementImpression.where( user_impression_options ).first
      if existing_impression
        existing_impression.update(
          impressions_count: existing_impression.impressions_count + 1,
          request_ip: options[:request_ip]
        )
        return
      end
      AnnouncementImpression.create( user_impression_options.merge(
        request_ip: options[:request_ip],
        impressions_count: 1
      ) )
      return
    end

    request_impression_options = base_impression_options.merge( request_ip: options[:request_ip] )
    existing_impression = AnnouncementImpression.where( request_impression_options ).first
    if existing_impression
      existing_impression.update(
        impressions_count: existing_impression.impressions_count + 1
      )
      return
    end
    AnnouncementImpression.create( request_impression_options.merge(
      impressions_count: 1
    ) )
  end
end

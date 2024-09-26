# frozen_string_literal: true

class AnnouncementDismissal < ApplicationRecord
  belongs_to :announcement
  belongs_to :user

  validates_uniqueness_of :user_id, scope: :announcement_id
end

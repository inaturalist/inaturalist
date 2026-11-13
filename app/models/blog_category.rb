# frozen_string_literal: true

class BlogCategory < ApplicationRecord
  extend FriendlyId
  friendly_id :label, use: [:slugged, :scoped, :history], scope: :site, reserved_words: %w(all)

  belongs_to :site
  has_many :posts, dependent: :restrict_with_error

  validates :label, presence: true
  validates :slug, presence: true

  def should_generate_new_friendly_id?
    label_changed? || super
  end
end

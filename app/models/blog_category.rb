# frozen_string_literal: true

class BlogCategory < ApplicationRecord
  extend FriendlyId
  friendly_id :label, use: [:slugged, :scoped, :history], scope: :site, reserved_words: %w(all)

  belongs_to :site, required: true
  has_many :posts, dependent: :restrict_with_error

  validates :label, presence: true, uniqueness: { scope: :site_id, case_sensitive: false }
  validates :position, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than: 2**31,
    allow_nil: true
  }
  validates :slug, presence: true

  def should_generate_new_friendly_id?
    label_changed? || super
  end
end

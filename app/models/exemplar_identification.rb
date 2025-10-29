# frozen_string_literal: true

class ExemplarIdentification < ApplicationRecord
  acts_as_elastic_model

  belongs_to :identification
  belongs_to :nominated_by_user, class_name: "User"

  acts_as_votable
  # acts_as_votable automatically includes `has_subscribers` but
  # we don't want people to subscribe to ExemplarIdentifications. Without this,
  # voting on ExemplarIdentification would invoke auto-subscription to the votable
  SUBSCRIBABLE = false

  validate :identification_body_has_text

  def identification_body_has_text
    return if identification && !identification.body&.strip&.blank?

    errors.add( :identification, "requires a body" )
  end

  def votable_callback
    self.wait_for_index_refresh = true
    elastic_index!
  end
end

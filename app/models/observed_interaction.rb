# frozen_string_literal: true

class ObservedInteraction < ApplicationRecord
  belongs_to :subject_observation, class_name: "Observation"
  belongs_to :object_observation, class_name: "Observation"
  belongs_to :user
  has_many :annotations, as: :resource, dependent: :destroy, inverse_of: :resource

  validates :subject_observation_id, presence: true
  validates :object_observation_id, presence: true
  validates :object_observation_id, uniqueness: { scope: :subject_observation_id }
  validates :annotations, presence: true
  validate :observation_cannot_interact_with_self

  accepts_nested_attributes_for :annotations

  def to_s
    "<ObservedInteraction #{id} #{to_plain_s}"
  end

  def to_plain_s
    [
      subject_observation.taxon.name,
      annotations.first.controlled_value.label,
      object_observation.taxon.name
    ].join( " " )
  end

  def observation_cannot_interact_with_self
    return unless subject_observation_id == object_observation_id

    errors.add( :subject_observation_id, "must interact with a different observation" )
  end
end

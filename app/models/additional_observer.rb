# frozen_string_literal: true

class AdditionalObserver < ApplicationRecord
  belongs_to :observation
  belongs_to :user
  belongs_to :added_by_user, class_name: "User"

  validates_presence_of :observation, :user, :added_by_user
  validates_uniqueness_of :user_id, scope: :observation_id
  validate :user_is_not_the_creator
  validate :added_by_user_is_the_creator

  after_save :update_observation_index
  after_destroy :update_observation_index

  # The creator can't be listed as their own additional observer
  def user_is_not_the_creator
    return unless observation && user_id

    if observation.user_id == user_id
      errors.add( :user, :cannot_be_the_creator )
    end
  end

  # Only the observation's creator (or a site admin) may add additional observers
  def added_by_user_is_the_creator
    return unless observation && added_by_user_id

    unless observation.user_id == added_by_user_id || added_by_user&.is_admin?
      errors.add( :added_by_user, :must_be_the_creator )
    end
  end

  def update_observation_index
    return unless ( o = Observation.find_by_id( observation_id ) )

    o.elastic_index!
    true
  end
end

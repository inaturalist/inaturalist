# frozen_string_literal: true

# Project on an ordered list a user has selected
class ProjectFave < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates_presence_of :project
  validates_presence_of :user

  validates :project_id, uniqueness: { scope: :user_id }
  validate :only_seven_projects_per_user

  LIMIT_PER_USER = 7

  def only_seven_projects_per_user
    return unless user && user.project_faves.count >= LIMIT_PER_USER

    errors.add( :base, :only_seven_projects )
  end
end

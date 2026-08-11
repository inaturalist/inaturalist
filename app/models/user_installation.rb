# frozen_string_literal: true

class UserInstallation < ApplicationRecord
  belongs_to :user
  belongs_to :oauth_application
  has_many :user_installation_activities, dependent: :delete_all
end

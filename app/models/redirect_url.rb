# frozen_string_literal: true

class RedirectUrl < ApplicationRecord
  belongs_to :user

  validates :user, presence: true
  validates :play_store_url, presence: true, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }
  validates :app_store_url, presence: true, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }
end

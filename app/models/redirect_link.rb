# frozen_string_literal: true

class RedirectLink < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :user, presence: true
  validates :play_store_url, presence: true,
    format: {
      with: URI::DEFAULT_PARSER.make_regexp( %w(http https) ),
      message: "must be a valid URL"
    }
  validates :app_store_url, presence: true,
    format: {
      with: URI::DEFAULT_PARSER.make_regexp( %w(http https) ),
      message: "must be a valid URL"
    }
end

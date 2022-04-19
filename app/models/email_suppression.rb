# frozen_string_literal: true

class EmailSuppression < ApplicationRecord
  belongs_to :user
  # These are the names of sendgrid suppression groups specified on Sendgrid
  # The IDs of the suppression groups that we actually use when sending emails
  # are specified in config/config.yml.
  ACCOUNT_EMAILS = "account_emails"
  BLOCKS = "blocks"
  BOUNCES = "bounces"
  DONATION_EMAILS = "donation_emails"
  INVALID_EMAILS = "invalid_emails"
  NEWS_EMAILS = "news_from_inaturalist"
  SPAM_REPORTS = "spam_reports"
  TRANSACTIONAL_EMAILS = "transactional_emails"
  UNSUBSCRIBES = "unsubscribes"

  SUPRESSION_TYPES = [
    ACCOUNT_EMAILS,
    DONATION_EMAILS,
    NEWS_EMAILS,
    TRANSACTIONAL_EMAILS,
    BOUNCES,
    BLOCKS,
    INVALID_EMAILS,
    SPAM_REPORTS,
    UNSUBSCRIBES
  ].freeze

  validates :suppression_type, inclusion: { in: SUPRESSION_TYPES }
end

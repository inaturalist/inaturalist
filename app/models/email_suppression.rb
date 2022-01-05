# frozen_string_literal: true

class EmailSuppression < ApplicationRecord
  validates :suppression_type, inclusion: { in: %w( account_emails donation_emails news_from_inaturalist
                                                    transactional_emails bounces blocks invalid_emails
                                                    spam_reports unsubscribes ) }

  # These are the names of endgrid suppression groups specified on Sendgrid
  # The IDs of the suppression groups that we actually use when sending emails
  # are specified in config/config.yml.
  ACCOUNT_EMAILS = "account_emails"
  DONATION_EMAILS = "donation_emails"
  NEWS_EMAILS = "news_from_inaturalist"
  TRANSACTIONAL_EMAILS = "transactional_emails"
  BOUNCES = "bounces"
  BLOCKS = "blocks"
  INVALID_EMAILS = "invalid_emails"
  SPAM_REPORTS = "spam_reports"
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
end

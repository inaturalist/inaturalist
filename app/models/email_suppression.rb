class EmailSuppression < ApplicationRecord
  validates :suppression_type, inclusion: { in: %w( account_emails donation_emails news_from_inaturalist
                                                    transactional_emails bounces blocks invalid_emails
                                                    spam_reports unsubscribes ) }

  # These are the names of endgrid suppression groups specified on Sendgrid
  # The IDs of the suppression groups that we actually use when sending emails
  # are specified in config/config.yml.
  allowed_types = [
    "account_emails",
    "donation_emails",
    "news_from_inaturalist",
    "transactional_emails",
    "bounces",
    "blocks",
    "invalid_emails",
    "spam_reports",
    "unsubscribes"
  ]

  ACCOUNT_EMAILS = allowed_types[0]
  DONATION_EMAILS = allowed_types[1]
  NEWS_EMAILS = allowed_types[2]
  TRANSACTIONAL_EMAILS = allowed_types[3]
  BOUNCES = allowed_types[4]
  BLOCKS = allowed_types[5]
  INVALID_EMAILS = allowed_types[6]
  SPAM_REPORTS = allowed_types[7]
  UNSUBSCRIBES = allowed_types[8]

  SUPRESSION_TYPES = allowed_types
end

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

  GROUP_TYPES = [
    ACCOUNT_EMAILS,
    DONATION_EMAILS,
    NEWS_EMAILS,
    TRANSACTIONAL_EMAILS
  ].freeze

  SENDGRID_REST_OPTS = { Authorization: "Bearer #{CONFIG&.sendgrid&.api_key}" }.freeze

  validates :suppression_type, inclusion: { in: SUPRESSION_TYPES }

  def to_s
    "<EmailSuppression #{id} #{suppression_type} />"
  end

  def delete_url_for_group_type
    return nil unless sendgrid_api_available?

    groups_resp = RestClient.get( "https://api.sendgrid.com/v3/asm/groups", SENDGRID_REST_OPTS )
    group_ids = JSON.parse( groups_resp ).each_with_object( {} ) do | group, memo |
      memo[group["name"].parameterize.underscore] = group["id"]
    end
    "https://api.sendgrid.com/v3/asm/groups/#{group_ids[suppression_type]}/suppressions/#{email}"
  end

  def destroy_remote
    return nil unless sendgrid_api_available?

    delete_url = if EmailSuppression::GROUP_TYPES.include?( suppression_type )
      delete_url_for_group_type
    elsif suppression_type == UNSUBSCRIBES
      "https://api.sendgrid.com/v3/asm/suppressions/global/#{email}"
    else
      "https://api.sendgrid.com/v3/suppression/#{suppression_type}/#{email}"
    end
    RestClient.delete( delete_url, SENDGRID_REST_OPTS )
  end

  def self.destroy_for_email( email, options = {} )
    scope = EmailSuppression.where( email: email )
    scope = scope.where( suppression_type: options[:only] ) unless options[:only].blank?
    scope = scope.where( "suppression_type NOT IN ?", options[:except] ) unless options[:except].blank?
    scope.each do | suppression |
      suppression.destroy_remote
      suppression.destroy
    rescue RestClient::Exception => e
      Rails.logger.error "Failed to destroy suppression on Sendgrid: #{suppression}, #{e}"
    end
  end

  private

  def sendgrid_api_available?
    !!CONFIG&.sendgrid&.api_key
  end
end

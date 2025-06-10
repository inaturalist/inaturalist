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

  def self.new_after_remote( attrs )
    user = attrs[:user] || User.find_by_id( attrs[:user_id] )
    email = attrs[:email] || user.email
    asm_group_id = SendgridService.asm_group_ids[attrs[:suppression_type]]
    SendgridService.post_group_suppression( email, asm_group_id )
    new( attrs )
  end

  def delete_url_for_group_type
    return nil unless sendgrid_api_available?

    group_id = SendgridService.asm_group_ids[suppression_type]
    "https://api.sendgrid.com/v3/asm/groups/#{group_id}/suppressions/#{email}"
  end

  def destroy_remote
    return nil unless sendgrid_api_available?

    if EmailSuppression::GROUP_TYPES.include?( suppression_type )
      asm_group_id = SendgridService.asm_group_ids[suppression_type]
      SendgridService.delete_group_suppression( email, asm_group_id )
      return
    end

    if suppression_type == UNSUBSCRIBES
      SendgridService.delete_global_suppression( email )
      return
    end

    if suppression_type == BOUNCES
      SendgridService.delete_bounce_suppression( email )
      return
    end

    if suppression_type == SPAM_REPORTS
      SendgridService.delete_spam_report_suppression( email )
      return
    end

    if suppression_type == BLOCKS
      SendgridService.delete_block_suppression( email )
      return
    end

    if suppression_type == INVALID_EMAILS
      SendgridService.delete_invalid_email( email )
      return
    end

    raise "We don't know how to delete a suppression of type #{suppression_type}"
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

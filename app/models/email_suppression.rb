# frozen_string_literal: true

class EmailSuppression < ApplicationRecord
  belongs_to :user

  # These are the names of sendgrid suppression groups specified on Sendgrid
  # The IDs of the suppression groups that we actually use when sending emails
  # are specified in config/config.yml.
  ACCOUNT_EMAILS = "account_emails"
  ACTIVITY = "activity"
  BLOCKS = "blocks"
  BOUNCES = "bounces"
  DONATION_EMAILS = "donation_emails"
  FEEDBACK = "feedback"
  INVALID_EMAILS = "invalid_emails"
  MESSAGES = "messages"
  NEWS_FROM_INATURALIST = "news_from_inaturalist"
  ONBOARDING = "onboarding"
  SPAM_REPORTS = "spam_reports"
  TRANSACTIONAL_EMAILS = "transactional_emails"
  UNSUBSCRIBES = "unsubscribes"

  # Sendgrid has a number of different kinds of suppressions, not all of which
  # are under the user's control
  SUPRESSION_TYPES = [
    ACCOUNT_EMAILS,
    ACTIVITY,
    BLOCKS,
    BOUNCES,
    DONATION_EMAILS,
    FEEDBACK,
    INVALID_EMAILS,
    MESSAGES,
    NEWS_FROM_INATURALIST,
    ONBOARDING,
    SPAM_REPORTS,
    TRANSACTIONAL_EMAILS,
    UNSUBSCRIBES
  ].freeze

  # These are the unsubscribe groups that iNat creates and users can
  # selectively add themselves to using unsubscribe links in email footers
  GROUP_TYPES = [
    ACCOUNT_EMAILS,
    ACTIVITY,
    DONATION_EMAILS,
    FEEDBACK,
    MESSAGES,
    NEWS_FROM_INATURALIST,
    ONBOARDING,
    TRANSACTIONAL_EMAILS
  ].freeze

  # Sendgrid webhook even types
  GROUP_UNSUBSCRIBE = "group_unsubscribe"
  GROUP_RESUBSCRIBE = "group_resubscribe"

  validates :suppression_type, inclusion: { in: SUPRESSION_TYPES }
  validates :email, presence: true, format: Devise.email_regexp

  before_validation :set_email_from_user, on: :create

  def to_s
    "<EmailSuppression #{id} #{suppression_type} />"
  end

  def set_email_from_user
    self.email ||= user&.email
  end

  def self.new_after_remote( attrs )
    user = attrs[:user] || User.find_by_id( attrs[:user_id] )
    email = attrs[:email] || user.email
    asm_group_id = SendgridService.asm_group_ids[attrs[:suppression_type]]
    SendgridService.post_group_suppression( email, asm_group_id )
    new( attrs )
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

  # Sendgrid webhook events tell us about things like unsubscribe and
  # resubscribe events in near-realtime, letting us updating corresponding
  # local state before our regular sync process handles things like
  # suppressions
  def self.handle_sendgrid_webhook_event( sendgrid_event )
    event = sendgrid_event.to_h.symbolize_keys
    # We don't need to process events that we don't care about
    return unless [GROUP_RESUBSCRIBE, GROUP_UNSUBSCRIBE].include?( event[:event] )

    # We only need to do things if we can find a corresponding user
    return unless ( user = User.find_by_email( event[:email] ) )

    group_name, _group_id = SendgridService.asm_group_ids.detect do | _name, id |
      id == event[:asm_group_id]
    end
    # If we don't know about the unsusbscribe group specified, we don't do anything
    return if group_name.blank?

    if event[:event] == GROUP_UNSUBSCRIBE
      # Create a local EmailSuppression record if necessary
      unless user.email_suppressions.where( suppression_type: group_name ).exists?
        user.email_suppressions.create!( email: user.email, suppression_type: group_name )
      end

      # Keep local prefs in sync with suppressions
      # TODO: remove when all relevant prefs have been transitioned to email suppressions
      if event[:asm_group_id] == SendgridService.asm_group_ids[EmailSuppression::MESSAGES]
        user.update( prefers_message_email_notification: false )
      end
    elsif event[:event] == GROUP_RESUBSCRIBE
      # Delete any local suppressions
      user.email_suppressions.where( suppression_type: group_name ).delete_all

      # Keep local prefs in sync
      # TODO: remove when all relevant prefs have been transitioned to email suppressions
      if event[:asm_group_id] == SendgridService.asm_group_ids[EmailSuppression::MESSAGES]
        user.update( prefers_message_email_notification: true )
      end
    end
  end

  private

  def sendgrid_api_available?
    !!CONFIG&.sendgrid&.api_key
  end
end

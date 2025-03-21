# frozen_string_literal: true

class Message < ApplicationRecord
  acts_as_spammable fields: [:subject, :body],
    user: :from_user

  blockable_by ->( message ) { message.to_user_id },
    blockable_user_id: ->( message ) { message.from_user_id }

  requires_privilege :speech, if: proc {| message |
    message.from_user_id == message.user_id && (
      message.thread_id.blank? || message.thread_id == message.id
    )
  }
  # TODO: uncomment to strictly enforce email confirmation for interaction
  # requires_privilege :interaction, if: proc {| message |
  #   message.from_user_id == message.user_id && (
  #     message.thread_id.blank? || message.thread_id == message.id
  #   )
  # }

  belongs_to :user
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"

  validates_presence_of :user
  validates :from_user_id, presence: true, numericality: { greater_than: 0 }
  validates :to_user_id, presence: true, numericality: { greater_than: 0 }
  validate :validate_to_not_from
  validates :body, presence: true
  before_create :set_read_at, :set_subject_for_reply
  after_save :set_thread_id
  after_create :deliver_email

  scope :inbox, -> { where( "user_id = to_user_id" ) } # .select("DISTINCT ON (thread_id) messages.*")
  scope :outbox, -> { where( "user_id = from_user_id" ) } # .select("DISTINCT ON (thread_id) messages.*")
  scope :unread, -> { where( "read_at IS NULL" ) }

  INBOX = "inbox"
  SENT = "sent"
  BOXES = [INBOX, SENT].freeze

  attr_accessor :html, :skip_email

  # When we added sent_at, we could not populate it because it was impossible
  # to distinguish between messages with no to_user_copy because the sender
  # was suspended or because the receiver manually deleted their copy, so we
  # need this crude date filter to prevent us from redelivering ancient
  # messages that the recipient deleted.
  RESEND_UNSENT_RELEASE_DATE = Date.parse( "2025-02-03" )

  def self.resend_unsent_for_user( user )
    user = User.find_by_id( user ) unless user.is_a?( User )
    return unless user

    scope = user.messages.outbox.
      where( "created_at > ?", RESEND_UNSENT_RELEASE_DATE ).
      where( "sent_at IS NULL" )
    scope.find_each do | msg |
      next if msg.sent?

      msg.send_message
    end
  end

  def to_s
    "<Message #{id} user:#{user_id} from:#{from_user_id} to:#{to_user_id} subject:#{subject.to_s[0..10]}>"
  end

  def send_message
    return if from_user.suspended? || known_spam?

    reload
    new_message = dup
    new_message.user = to_user
    new_message.read_at = nil
    new_message.save!
    update( sent_at: Time.now )
  end

  def to_user_copy
    return self if to_user_id == user_id

    to_user.messages.inbox.where( thread_id: thread_id ).detect {| m | m.body == body }
  end

  def from_user_copy
    return self if from_user_id == user_id

    from_user.messages.outbox.where( thread_id: thread_id ).detect {| m | m.body == body }
  end

  def sent?
    !to_user_copy.blank?
  end

  def set_read_at
    if user_id == from_user_id || UserMute.where( user_id: to_user, muted_user_id: from_user ).exists?
      self.read_at = Time.now
    end
    true
  end

  def set_thread_id
    if thread_id.blank?
      Message.where( id: id ).update_all( thread_id: id )
    end
    true
  end

  def thread_flags
    Flag.where( flaggable_type: "Message" ).
      joins( "JOIN messages ON messages.id = flags.flaggable_id" ).
      where( "messages.thread_id = ?", thread_id ).
      where( "flags.user_id = ?", user_id )
  end

  def set_subject_for_reply
    return true if thread_id.blank?

    first = Message.where( thread_id: thread_id, user_id: user_id ).order( "id asc" ).first
    if first && first != self
      self.subject = first.subject
      self.subject = "Re: #{subject}" unless subject.to_s =~ /^Re:/
    end
    true
  end

  def validate_to_not_from
    return unless to_user_id == from_user_id

    errors.add( :base, "You can't send a message to yourself" )
  end

  def deliver_email
    return true if user_id == from_user_id
    return true if skip_email
    return true if UserMute.where( user_id: to_user, muted_user_id: from_user ).exists?
    return true if UserBlock.where( user_id: to_user, blocked_user_id: from_user ).exists?
    return true if from_user.suspended? || known_spam?

    Emailer.delay( priority: USER_INTEGRITY_PRIORITY ).new_message( id )
    true
  end

  def flagged_with( flag, options = {} )
    evaluate_new_flag_for_spam( flag )
    return unless options[:action] == "resolved" && flag.flag == Flag::SPAM

    Message.
      delay( priority: USER_INTEGRITY_PRIORITY ).
      resend_unsent_for_user( user_id )
  end
end

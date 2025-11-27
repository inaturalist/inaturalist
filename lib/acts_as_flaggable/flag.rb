# frozen_string_literal: true

class Flag < ApplicationRecord
  include ActsAsUUIDable
  before_validation :set_uuid
  def set_uuid
    self.uuid ||= SecureRandom.uuid
    self.uuid = uuid.downcase
    true
  end
  SPAM = "spam"
  INAPPROPRIATE = "inappropriate"
  COPYRIGHT_INFRINGEMENT = "copyright infringement"
  ARTIFICIALLY_GENERATED_CONTENT = "artificially generated content"
  FLAGS = [
    SPAM,
    INAPPROPRIATE,
    COPYRIGHT_INFRINGEMENT,
    ARTIFICIALLY_GENERATED_CONTENT
  ].freeze
  TYPES = %w(CheckList Comment Guide GuideSection Identification List Message Observation Photo Place Post Project Sound
             Taxon User).freeze
  belongs_to :flaggable, polymorphic: true
  belongs_to :flaggable_parent, polymorphic: true
  belongs_to :flaggable_user, class_name: "User", foreign_key: "flaggable_user_id", inverse_of: :flags_as_flaggable_user

  has_subscribers to: {
    comments: { notification: "activity", include_owner: true }
  }
  notifies_subscribers_of :self,
    notification: "activity",
    include_owner: true,
    include_notifier: true,
    on: :update,
    if: lambda {| flag, _, subscription |
      # this is meant to address a problem where the flag resolver was getting notified they
      # they resolved a flag, and users shouldn't be notified of their own actions. This isn't
      # perfect though, as this affects all `update` notifications. But, resolved flags are almost
      # never updated, and even less so for reasons worth notifying
      return false if flag.resolver == subscription.user

      true
    },
    unless: proc {| flag |
      # existing flag whose comment has been changed
      flag.saved_change_to_id || !flag.saved_change_to_comment
    }
  auto_subscribes :resolver, on: :update, if: proc {| record, _resource |
    record.saved_change_to_resolved? && !record.resolver.blank? &&
      !record.resolver.subscriptions.where( resource_type: "Flag", resource_id: record.id ).exists?
  }

  # requires_privilege :interaction, unless: proc {| flag |
  #   flag.user_id.blank? ||
  #     flag.user_id.zero? ||
  #     ( flag.flaggable.respond_to?( :user ) && flag.flaggable.user.id == flag.user_id ) ||
  #     ( flag.flaggable.is_a?( Message ) && flag.flaggable.to_user_id == flag.user_id )
  # }

  blockable_by ->( flag ) { flag.flaggable.try( :user_id ) }, on: :create

  # NOTE: Flags belong to a user
  belongs_to :user, inverse_of: :flags
  belongs_to :resolver, class_name: "User", foreign_key: "resolver_id"
  has_many :comments, as: :parent, dependent: :destroy, validate: false
  attr_accessor :initial_comment_body

  before_save :check_resolved
  before_create :set_flaggable_user_id
  before_create :set_flaggable_content
  before_create :set_flaggable_parent

  after_create :notify_flaggable_on_create
  after_update :notify_flaggable_on_update
  after_destroy :notify_flaggable_on_destroy

  # A user can flag a specific flaggable with a specific flag once
  validates_length_of :flag, in: 3..256, allow_blank: false
  validates_length_of :comment, maximum: 256, allow_blank: true
  validates_uniqueness_of :user_id, scope: [
    :flaggable_id,
    :flaggable_type,
    :flag,
    # This only works if the validation is on create, i.e. no other user /
    # flaggable / flag combo can exist when resolved_at is null
    :resolved_at
  ], message: :already_flagged, on: :create
  validate :flaggable_type_valid
  validate :flag_not_about_duplicate, on: :create

  def to_s
    "<Flag #{id} user_id: #{user_id} flaggable_type: #{flaggable_type} flaggable_id: #{flaggable_id}>"
  end

  def flaggable_type_valid
    if Flag::TYPES.include?( flaggable_type )
      true
    else
      errors.add( :flaggable_type, "can't be flagged" )
    end
  end

  def flag_not_about_duplicate
    return true unless %w(Observation Photo).include?( flaggable_type )

    return true unless flag.to_s.downcase.include?( "duplicate" )

    errors.add( :flag, :not_about_duplicate )
  end

  def notify_flaggable_on_create
    if flaggable.respond_to?( :flagged_with )
      flaggable.flagged_with( self, action: "created" )
    end
    true
  end

  def notify_flaggable_on_update
    if flaggable.respond_to?( :flagged_with ) && saved_change_to_resolved?
      if resolved?
        flaggable.flagged_with( self, action: "resolved" )
      else
        flaggable.flagged_with( self, action: "unresolved" )
      end
    end
    true
  end

  def notify_flaggable_on_destroy
    if flaggable.respond_to?( :flagged_with )
      flaggable.flagged_with( self, action: "destroyed" )
    end
    true
  end

  def akismet_spam_flag?
    user_id.zero? && flag == Flag::SPAM
  end

  def as_indexed_json
    {
      id: id,
      flag: flag,
      comment: comment,
      user_id: user_id,
      resolver_id: resolver_id,
      resolved: resolved,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Helper class method to lookup all flags assigned
  # to all flaggable types for a given user.
  def self.find_flags_by_user( user )
    find( :all,
      conditions: ["user_id = ?", user.id],
      order: "created_at DESC" )
  end

  # Helper class method to look up all flags for
  # flaggable class name and flaggable id.
  def self.find_flags_for_flaggable( flaggable_str, flaggable_id )
    find( :all,
      conditions: ["flaggable_type = ? and flaggable_id = ?", flaggable_str, flaggable_id],
      order: "created_at DESC" )
  end

  # Helper class method to look up a flaggable object
  # given the flaggable class name and id
  def self.find_flaggable( flaggable_str, flaggable_id )
    flaggable_str.constantize.find( flaggable_id )
  end

  def self.instance_parent( instance )
    return unless instance

    instance_type = instance.class.polymorphic_name
    case instance_type
    when "Comment", "Post" then instance.parent
    when "Identification" then instance.observation
    when "Photo"
      if instance.observations.exists?
        instance.observations.first
      elsif instance.taxa.exists?
        instance.taxa.first
      elsif instance.guide_photos.exists?
        instance.guide_photos.first.guide_taxon
      end
    when "Sound"
      if instance.observations.exists?
        instance.observations.first
      end
    end
  end

  def self.instance_user( instance )
    return unless instance

    instance_type = instance.class.polymorphic_name
    case instance_type
    when "User" then instance
    when "Message" then instance.from_user
    else
      k, reflection = instance.class.reflections.detect do | r |
        r[1].class_name == "User" && r[1].macro == :belongs_to
      end
      if reflection
        instance.send( k )
      end
    end
  end

  def self.instance_content( instance )
    instance.try_methods( :body, :description )
  end

  def flagged_object
    return unless ( klass = Object.const_get( flaggable_type ) )

    klass.find_by_id( flaggable_id )
  end

  def check_resolved
    if will_save_change_to_resolved? && resolved
      self.resolved_at = Time.now
    elsif will_save_change_to_resolved?
      self.resolved_at = nil
      self.resolver = nil
      self.comment = nil
    end
    true
  end

  def set_flaggable_user_id
    return unless flaggable

    user = Flag.instance_user( flaggable )
    return if user.blank?

    self.flaggable_user_id = user.id
  end

  def set_flaggable_content
    return unless flaggable

    self.flaggable_content = Flag.instance_content( flaggable )
  end

  def set_flaggable_parent
    return unless flaggable

    self.flaggable_parent = Flag.instance_parent( flaggable )
  end

  def viewable_by?( user )
    if flaggable_type == "Message" && !( user && user.is_admin? )
      return false
    end

    return true if user&.is_curator?

    false
  end

  def flaggable_content_viewable_by?( user )
    !flaggable_content.blank? && viewable_by?( user )
  end

  def deletable_by?( user )
    return false if new_record? || user.blank?
    return true if user.is_admin?
    return true if user.id == user_id && !resolved? && comments.none?

    false
  end

  def resolvable_by?( user )
    return false unless user
    return true if user.is_curator? && ( user.id != flaggable_user_id || flaggable_type == "Taxon" )

    false
  end
end

class UserPrivilege < ActiveRecord::Base
  belongs_to :user
  belongs_to :revoke_user, class_name: "User"
  validates :user_id, uniqueness: { scope: :privilege }

  SPEECH = "speech"
  ORGANIZER = "organizer"
  COORDINATE_ACCESS = "coordinate_access"

  def self.earned_speech?( user )
    user.observations.verifiable.limit( 3 ).count == 3 || user.identifications.current.for_others.limit( 3 ).count == 3
  end

  def self.earned_organizer?( user )
    user.observations.verifiable.limit( 3 ).count == 50
  end

  def self.earned_coordinate_access?( user )
    user.observations.verifiable.count > 1000 || user.identifications.current.for_others.count > 1000
  end

  def self.check( user, privilege )
    user = User.find_by_id( user ) unless user.is_a?( User )
    # puts "UserPrivilege.check, user: #{user}"
    # puts "UserPrivilege.check, respond_to?( \"earned_#{privilege}?\".to_sym ): #{respond_to?( "earned_#{privilege}?".to_sym )}"
    unless user && respond_to?( "earned_#{privilege}?".to_sym )
      # puts "UserPrivilege.check, user or privilege check method missing"
      return
    end
    if existing = user.user_privileges.where( privilege: privilege ).first
      if send( "earned_#{privilege}?", user )
        # puts "UserPrivilege.check, user has still earned privilege #{privilege}"
        existing.restore!
      else
        # puts "UserPrivilege.check, revoking existing: #{existing}"
        existing.revoke!
      end
    elsif send( "earned_#{privilege}?", user )
      # puts "UserPrivilege.check, no existing, earned #{privilege}, adding UserPrivilege"
      UserPrivilege.create!( user: user, privilege: privilege )
    end
  end

  def restore!( options: {} )
    update_attributes( revoked_at: nil )
  end

  def revoke!( options: {} )
    update_attributes(
      revoked_at: Time.now,
      revoke_user: options[:revoke_user],
      revoke_reason: options[:revoke_reason]
    )
  end
end

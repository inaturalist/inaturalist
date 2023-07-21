# frozen_string_literal: true

module HasModeratorActions
  def self.included( base )
    base.extend ClassMethods
  end

  module ClassMethods
    # rubocop:disable Naming/PredicateName
    def has_moderator_actions( accepted_actions = nil )
      has_many :moderator_actions, as: :resource, dependent: :destroy
      include HasModeratorActions::InstanceMethods
      return unless accepted_actions

      cattr_accessor :accepted_moderator_actions
      self.accepted_moderator_actions = accepted_actions
    end
    # rubocop:enable Naming/PredicateName
  end

  module InstanceMethods
    def hidden?
      moderator_actions.sort_by( &:id ).last.try( :action ) == ModeratorAction::HIDE
    end

    def hideable_by?( u )
      return false unless u
      if self.is_a?( User )
        return false if self === u
      elsif self.user
        return false if self.user === u
      end
      u.is_admin? || u.is_curator?
    end

    def hidden_content_viewable_by?( u )
      return false unless u
      return true if hideable_by?( u )
      if self.is_a?( User )
        return true if self == u
      elsif self.user
        return self.user === u
      end
    end
  end

end

ActiveRecord::Base.include HasModeratorActions

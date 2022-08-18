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
  end
end

ActiveRecord::Base.include HasModeratorActions

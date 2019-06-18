module HasModeratorActions
  def self.included(base)
    base.extend ClassMethods
    include InstanceMethods
  end
  
  module ClassMethods
    def has_moderator_actions
      has_many :moderator_actions, as: :resource, dependent: :destroy
      include HasModeratorActions::InstanceMethods
    end
  end

  module InstanceMethods
    def hidden?
      moderator_actions.sort_by(&:id).last.try(:action) == ModeratorAction::HIDE
    end
  end
end
ActiveRecord::Base.send(:include, HasModeratorActions)

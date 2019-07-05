class ModeratorAction < ActiveRecord::Base
  HIDE = "hide"
  UNHIDE = "unhide"
  ACTIONS = [HIDE, UNHIDE]

  belongs_to :user, inverse_of: :moderator_actions
  belongs_to :resource, polymorphic: true, inverse_of: :moderator_actions
  validates :action, inclusion: ACTIONS
  validates :reason, length: { minimum: 10 }
  validate :only_staff_can_unhide, on: :create

  after_save :touch_resource

  def only_staff_can_unhide
    if user && action == UNHIDE && !user.is_admin?
      errors.add( :base, :only_staff_can_unhide )
    end
  end

  def as_indexed_json
    {
      id: id,
      created_at: created_at,
      created_at_details: ElasticModel.date_details( created_at ),
      user: user.as_indexed_json( no_details: true ),
      action: action,
      reason: reason
    }
  end

  def touch_resource
    resource.touch
    true
  end
end

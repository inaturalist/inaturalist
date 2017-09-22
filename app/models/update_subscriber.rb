class UpdateSubscriber < ActiveRecord::Base

  belongs_to :update_action
  belongs_to :subscriber, class_name: "User"

  validates_presence_of :subscriber

  blockable_by lambda {|user| update_action.resource_owner }

end

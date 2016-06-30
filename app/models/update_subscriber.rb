class UpdateSubscriber < ActiveRecord::Base

  belongs_to :update_action
  belongs_to :subscriber, class_name: "User"

end

class Marking < ActiveRecord::Base
  belongs_to :user
  belongs_to :observation
  belongs_to :marking_type
  
  validates_uniqueness_of :marking_type_id,
                          :scope => [:user_id, :observation_id],
                          :message => "You have already applied this marking to this observation."
end

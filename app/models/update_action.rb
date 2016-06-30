class UpdateAction < ActiveRecord::Base

  belongs_to :resource, polymorphic: true
  belongs_to :notifier, polymorphic: true
  belongs_to :resource_owner, class_name: "User"

  validates_presence_of :resource, :notifier

  # before_create :set_resource_owner

  # def set_resource_owner
  #   return if self.resource_owner_id
  #   self.resource_owner = resource && resource.respond_to?(:user) ? resource.user : nil
  # end

end

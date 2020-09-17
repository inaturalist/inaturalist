class Notifier < ActiveRecord::Base

  has_many :notifications_notifiers, dependent: :destroy
  belongs_to :resource, polymorphic: true
  has_many :notifications, through: :notifications_notifiers

end

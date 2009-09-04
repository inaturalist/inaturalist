class MarkingType < ActiveRecord::Base
  has_many :markings
  has_many :observations,
           :through => :markings
  
  validates_uniqueness_of :name
end

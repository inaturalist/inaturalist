class Source < ActiveRecord::Base
  has_many :taxa
  has_many :taxon_names
  has_many :taxon_ranges
  belongs_to :user
  
  validates_presence_of :title
  
  attr_accessor :html
  
  def user_name
    user.try(&:login) || "unknown"
  end
  
  def editable_by?(u)
    return false if u.blank?
    return true if u.is_curator?
    u.id == user_id
  end
end

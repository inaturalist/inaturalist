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
end

class Source < ActiveRecord::Base
  has_many :taxa
  has_many :taxon_names
  has_many :taxon_ranges
  
  validates_presence_of :title
end

class Source < ActiveRecord::Base
  has_many :taxa
  has_many :taxon_names
end

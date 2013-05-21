class Guide < ActiveRecord::Base
  attr_accessible :description, :latitude, :longitude, :place_id, :published_at, :title, :user_id
  belongs_to :user, :inverse_of => :guides
  has_many :guide_taxa, :inverse_of => :guide, :dependent => :destroy
end

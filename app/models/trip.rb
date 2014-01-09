class Trip < Post
  has_many :trip_taxa, :dependent => :destroy, :inverse_of => :trip
  has_many :trip_purposes, :dependent => :destroy
  has_many :taxa, :through => :trip_taxa
  accepts_nested_attributes_for :trip_purposes, :allow_destroy => true
  accepts_nested_attributes_for :trip_taxa, :allow_destroy => true

  before_validation :set_parent

  def set_parent
    self.parent ||= self.user
  end
end

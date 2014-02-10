class Trip < Post
  has_many :trip_taxa, :dependent => :destroy, :inverse_of => :trip
  has_many :trip_purposes, :dependent => :destroy
  has_many :taxa, :through => :trip_taxa
  belongs_to :place, :inverse_of => :trips
  accepts_nested_attributes_for :trip_purposes, :allow_destroy => true
  accepts_nested_attributes_for :trip_taxa, :allow_destroy => true

  before_validation :set_parent

  def set_parent
    self.parent ||= self.user
  end

  def trip_observations
    return Observation.where("1 = 2") if start_time.blank? || stop_time.blank?
    scope = Observation.by(user).where("observed_on = ? OR time_observed_at BETWEEN ? AND ?", start_time.to_date, start_time, stop_time).scoped
    scope = scope.in_place(place_id) unless place_id.blank?
    scope
  end

  def editable_by?(u)
    return false unless u
    user_id == u.id
  end
end

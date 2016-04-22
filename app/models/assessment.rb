class Assessment < ActiveRecord::Base
	belongs_to :project
	belongs_to :user
	belongs_to :taxon

  validates_presence_of :project, :user, :taxon

  has_many :sections, 
    -> { order('display_order DESC') }, 
    foreign_key: 'assessment_id',
    class_name: "AssessmentSection",
    dependent: :delete_all
  accepts_nested_attributes_for :sections, :allow_destroy => true
  validates_associated :sections

  scope :complete, -> { where("completed_at IS NOT NULL") }
  scope :incomplete, -> { where("completed_at IS NULL") }
  scope :with_conservation_status, lambda {|authority, status, place|
    scope = joins("INNER JOIN conservation_statuses ON assessments.taxon_id = conservation_statuses.taxon_id").
    where("conservation_statuses.authority = ? AND conservation_statuses.status = ?", authority, status)
    scope = if place
      scope.where("conservation_statuses.place_id = ?", place)
    else
      scope.where("conservation_statuses.place_id IS NULL")
    end
    scope
  }
  scope :dbsearch, lambda {|q| joins(:taxon).where("taxa.name ILIKE ? OR assessments.description ILIKE ?", "%#{q}%", "%#{q}%")}

  def taxon_name
     taxon.present? ? taxon.name : '<i>No Taxon</i>'.html_safe
  end

  def display_name
	   taxon_scientific_name = taxon.present? ? taxon.name : ''
	   description = self.description.blank? ? nil : self.description.truncate(60)
	   "<i>#{taxon_name}</i> #{description}".html_safe 
  end

  def to_param
    return nil if new_record?
    "#{id}-#{self.taxon_name.parameterize}"
  end

  def curated_by? user
    self.project.curated_by? user
  end

end

class Assessment < ActiveRecord::Base
	belongs_to :project
	belongs_to :user
	belongs_to :taxon

  validates_presence_of :project, :user, :taxon

  has_many :sections, :foreign_key => 'assessment_id', :class_name => "AssessmentSection", :dependent => :destroy
  accepts_nested_attributes_for :sections, :allow_destroy => true
  validates_associated :sections

  attr_accessible :taxon_id, :project_id, :description, :sections_attributes, :user_id

  def taxon_name
     self.taxon.present? ? self.taxon.name : '<i>No Taxon</i>'.html_safe
  end

  def display_name
	   taxon_name = self.taxon_name
	   taxon_scientific_name = self.taxon.present? ? self.taxon.scientific_name : ''
	   "#{taxon_name} #{self.created_at.strftime('%Y')} <i>#{taxon_scientific_name}</i>".html_safe 
  end

  def to_param
    return nil if new_record?
    "#{id}-#{self.taxon_name.parameterize}"
  end

  def curated_by? user
    self.project.curated_by? user
  end

end

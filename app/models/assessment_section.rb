class AssessmentSection < ActiveRecord::Base
	belongs_to :assessment #, :foreign_key => 'assessment_id', :class_name => "Assessment"
	belongs_to :user

  default_scope order('id ASC')

  attr_accessible :title, :body, :user_id

	validates_presence_of :user, :title, :body # , :assessment

  has_many :comments, :as => :parent, :dependent => :destroy
	has_subscribers :to => {:comments => {:notification => "activity", :include_owner => true}}

	after_create :subscribe_curators_to_section	  
	def subscribe_curators_to_section
	  assessment.project.project_users.curators.each { |u| Subscription.create(:user => u.user, :resource => self) }
	end

  def display_title
  	self.title.length > 11 ? "#{self.title[0..10]}..." : self.title
  end

  def to_param
    return nil if new_record?
    "#{id}-#{self.title.parameterize}"
  end

end

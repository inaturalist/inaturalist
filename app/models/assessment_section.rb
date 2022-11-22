class AssessmentSection < ApplicationRecord
	belongs_to :assessment
	belongs_to :user

	validates_presence_of :user, :title, :body # , :assessment

  has_many :comments, :as => :parent, :dependent => :destroy
	has_subscribers :to => {:comments => {:notification => "activity", :include_owner => true}}

	after_create :subscribe_curators_to_section	  

  ALLOWED_TAGS = %w(
    a abbr acronym b blockquote br cite code dl dt em embed h1 h2 h3 h4 h5 h6
    hr i iframe img li object ol p param pre small strong sub sup tt ul table
    thead tbody tfood tr th td s
  )

  ALLOWED_ATTRIBUTES = %w(
    href src width height alt cite title class name xml:lang abbr value align
    colspan
  )

	def subscribe_curators_to_section
	  assessment.project.project_users.curators.each { |u| Subscription.create(:user => u.user, :resource => self) }
    true
	end

  def display_title
  	self.title.length > 11 ? "#{self.title[0..10]}..." : self.title
  end

  def to_param
    return nil if new_record?
    "#{id}-#{self.title.parameterize}"
  end

end

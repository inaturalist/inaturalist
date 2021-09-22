class SiteFeaturedProject < ApplicationRecord

  belongs_to :site
  belongs_to :project
  belongs_to :user

  validates_presence_of :site
  validates_presence_of :project
  validates_presence_of :user

  validates_uniqueness_of :project_id, scope: :site_id

  after_commit :index_project
  after_destroy :index_project

  def index_project
    project.reload
    project.wait_for_index_refresh = true
    project.elastic_index!
  end

  def as_indexed_json
    {
      site_id: site_id,
      noteworthy: noteworthy,
      featured_at: updated_at
    }
  end

end

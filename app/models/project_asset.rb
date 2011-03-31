class ProjectAsset < ActiveRecord::Base
  belongs_to :project
  has_attached_file :asset,
    :path => ":rails_root/public/attachments/:class/:id-:filename",
    :url => "/attachments/:class/:id-:filename"
  
  validates_attachment_presence :asset
  validates_presence_of :project_id
end

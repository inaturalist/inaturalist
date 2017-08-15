class ProjectAsset < ActiveRecord::Base
  belongs_to :project
  has_attached_file :asset,
    :path => ":rails_root/public/attachments/:class/:id-:filename",
    :url => "/attachments/:class/:id-:filename"
  do_not_validate_attachment_file_type :asset
  validates_attachment_presence :asset
  validates_attachment_size :asset, :in => 0..5.megabyte, :message => "must be less than 5 MB"
  validates_presence_of :project_id
end

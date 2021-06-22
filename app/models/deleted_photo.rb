class DeletedPhoto < ApplicationRecord
  belongs_to :user
  belongs_to :photo
  scope :still_in_s3, ->{ where(removed_from_s3: false) }
end

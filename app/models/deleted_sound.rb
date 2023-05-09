class DeletedSound < ApplicationRecord
  belongs_to :user
  belongs_to :sound
  scope :still_in_s3, ->{ where(removed_from_s3: false) }
end

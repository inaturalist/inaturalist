class DeletedUser < ApplicationRecord
  validates :user_id, uniqueness: true
end

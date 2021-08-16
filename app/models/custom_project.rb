class CustomProject < ApplicationRecord
  belongs_to :project
  validates_presence_of :project_id
end

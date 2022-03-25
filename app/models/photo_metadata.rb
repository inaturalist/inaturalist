class PhotoMetadata < ApplicationRecord
  self.primary_key = :photo_id
  self.table_name = "photo_metadata"

  belongs_to :photo

  serialize :metadata, CompressedYAMLColumn
end

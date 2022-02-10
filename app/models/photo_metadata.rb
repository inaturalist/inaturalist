class PhotoMetadata < ApplicationRecord
  self.table_name = "photo_metadata"
  belongs_to :photo

  serialize :metadata, CompressedYAMLColumn

end

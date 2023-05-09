class FileExtension < ApplicationRecord
  validates_uniqueness_of :extension

  def self.id_for_extension( extension )
    lookup_extension = extension.blank? ? "" : extension.strip
    if existing_record = FileExtension.where( extension: lookup_extension ).first
      return existing_record.id
    end
    new_record = FileExtension.create( extension: lookup_extension )
    return new_record.id
  end
end

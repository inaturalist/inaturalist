class FileExtension < ApplicationRecord
  validates_uniqueness_of :extension

  @@extension_ids = { }

  def self.id_for_extension( extension )
    lookup_extension = extension.blank? ? "" : extension.strip
    return @@extension_ids[lookup_extension] if @@extension_ids[lookup_extension]
    if existing_record = FileExtension.where( extension: lookup_extension ).first
      @@extension_ids[lookup_extension] = existing_record.id
      return existing_record.id
    end
    new_record = FileExtension.create( extension: lookup_extension )
    @@extension_ids[lookup_extension] = new_record.id
    return new_record.id
  end
end

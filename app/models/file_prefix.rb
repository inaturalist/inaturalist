class FilePrefix < ApplicationRecord
  validates_uniqueness_of :prefix

  @@prefix_ids = { }

  def self.id_for_prefix( prefix )
    lookup_prefix = prefix.blank? ? "" : prefix.strip
    return @@prefix_ids[lookup_prefix] if @@prefix_ids[lookup_prefix]
    if existing_record = FilePrefix.where( prefix: lookup_prefix ).first
      @@prefix_ids[lookup_prefix] = existing_record.id
      return existing_record.id
    end
    new_record = FilePrefix.create( prefix: lookup_prefix )
    @@prefix_ids[lookup_prefix] = new_record.id
    return new_record.id
  end
end

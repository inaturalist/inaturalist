class FilePrefix < ApplicationRecord
  validates_uniqueness_of :prefix

  def self.id_for_prefix( prefix )
    lookup_prefix = prefix.blank? ? "" : prefix.strip
    if existing_record = FilePrefix.where( prefix: lookup_prefix ).first
      return existing_record.id
    end
    new_record = FilePrefix.create( prefix: lookup_prefix )
    return new_record.id
  end
end

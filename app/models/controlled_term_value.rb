class ControlledTermValue < ApplicationRecord

  belongs_to :controlled_attribute, class_name: "ControlledTerm"
  belongs_to :controlled_value, class_name: "ControlledTerm"
  validates_presence_of :controlled_value_id
  validates_presence_of :controlled_attribute_id
  validates_uniqueness_of :controlled_value_id, scope: :controlled_attribute_id

  after_commit :reindex_terms

  def reindex_terms
    ControlledTerm.elastic_index!( ids: [controlled_attribute_id, controlled_value_id].compact )
    true
  end

end

#encoding: utf-8
class Annotation < ActiveRecord::Base

  acts_as_votable
  # acts_as_votable automatically includes `has_subscribers` but
  # we don't want people to subscribe to annotations. Without this,
  # voting on annotations would invoke auto-subscription to the votable
  SUBSCRIBABLE = false

  belongs_to :controlled_attribute, class_name: "ControlledTerm"
  belongs_to :controlled_value, class_name: "ControlledTerm"
  belongs_to :resource, polymorphic: true
  belongs_to :user

  validates_presence_of :resource
  validates_presence_of :controlled_attribute
  # limiting the resource type to Observation to begin with
  validate :resource_is_an_observation
  validate :attribute_is_an_attribute
  validate :value_is_a_value
  validate :value_belongs_to_attribute
  validate :attribute_belongs_to_taxon
  validate :value_belongs_to_taxon
  validate :multiple_values
  validates_uniqueness_of :controlled_value_id,
    scope: [:resource_type, :resource_id, :controlled_attribute_id]

  after_save :index_observation
  after_destroy :index_observation

  attr_accessor :skip_indexing

  def resource_is_an_observation
    if !resource.is_a?(Observation)
      errors.add(:resource_type, "must be an Observation")
    end
  end

  def attribute_is_an_attribute
    if !(controlled_attribute && ControlledTerm.attributes.exists?(controlled_attribute.id))
      errors.add(:controlled_attribute_id, "must be an attribute")
    end
  end

  def value_is_a_value
    if !(controlled_value && ControlledTerm.values.exists?(controlled_value.id))
      errors.add(:controlled_value_id, "must be a value")
    end
  end

  def value_belongs_to_attribute
    if controlled_value &&
       (!controlled_attribute || !controlled_attribute.values.include?(controlled_value))
      errors.add(:controlled_value, "must belong to attribute")
    end
  end

  def attribute_belongs_to_taxon
    if taxon_id && !ControlledTerm.for_taxon(taxon_id).include?(controlled_attribute)
      errors.add(:controlled_attribute, "must belong to taxon")
    end
  end

  def value_belongs_to_taxon
    return unless controlled_value
    if taxon_id &&
       (controlled_value && !ControlledTerm.for_taxon(taxon_id).include?(controlled_value))
      errors.add(:controlled_value, "must belong to taxon")
    end
  end

  def multiple_values
    return unless controlled_attribute
    return if controlled_attribute.multivalued?
    scope = Annotation.where( controlled_attribute: controlled_attribute,
      resource: resource)
    unless new_record?
      scope = scope.where("id != ?", id)
    end
    if scope.count > 0
      errors.add(:controlled_attribute, "cannot have multiple values")
    end
  end

  def taxon_id
    if resource.is_a?(Observation)
      resource.taxon_id
    end
  end

  def vote_score
    get_likes.size - get_dislikes.size
  end

  def votable_callback
    index_observation
  end

  def as_indexed_json(options={})
    {
      controlled_attribute_id: controlled_attribute_id,
      controlled_value_id: controlled_value_id,
      attribute_value: [controlled_attribute_id, controlled_value_id].join("|"),
      vote_score: vote_score
    }
  end

  def index_observation
    if resource.is_a?(Observation) && !skip_indexing
      Observation.elastic_index!(ids: [resource.id])
    end
  end

end

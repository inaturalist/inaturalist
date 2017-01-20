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
  belongs_to :observation_field_value

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

  after_create :index_observation_later
  after_save :index_observation_later
  after_destroy :index_observation_later

  attr_accessor :skip_indexing

  def resource_is_an_observation
    if !resource.is_a?(Observation)
      errors.add(:resource_type, "must be an Observation")
    end
  end

  def attribute_is_an_attribute
    if !(controlled_attribute && !controlled_attribute.is_value?)
      errors.add(:controlled_attribute_id, "must be an attribute")
    end
  end

  def value_is_a_value
    if !(controlled_value && controlled_value.is_value?)
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
    if taxon && !controlled_attribute.applicable_to_taxon(taxon)
      errors.add(:controlled_attribute, "must belong to taxon")
    end
  end

  def value_belongs_to_taxon
    return unless controlled_value
    if taxon && !controlled_value.applicable_to_taxon(taxon)
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
    taxon.try(:id)
  end

  def taxon
    if resource.is_a?(Observation)
      resource.taxon
    end
  end

  def vote_score
    if votes_for.loaded?
      votes_for.select{ |v| v.vote_flag? }.size -
        votes_for.select{ |v| !v.vote_flag? }.size
    else
      get_likes.size - get_dislikes.size
    end
  end

  def votable_callback
    index_observation_later
  end

  def as_indexed_json(options={})
    {
      uuid: uuid,
      controlled_attribute_id: controlled_attribute_id,
      controlled_value_id: controlled_value_id,
      concatenated_attr_val: [controlled_attribute_id, controlled_value_id].join("|"),
      vote_score: vote_score
    }
  end

  def index_observation_later
    if resource.is_a?(Observation) && !skip_indexing
      Observation.elastic_index!(ids: [resource.id], delay: true)
    end
  end

end

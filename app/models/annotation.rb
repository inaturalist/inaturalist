#encoding: utf-8
class Annotation < ActiveRecord::Base

  acts_as_votable
  blockable_by lambda {|annotation| annotation.resource.try(:user_id) }

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
  validate :no_other_annotations_of_blocking_values
  validate :no_other_annotations_if_this_is_blocking
  validates_uniqueness_of :controlled_value_id,
    scope: [:resource_type, :resource_id, :controlled_attribute_id]

  after_create :index_observation, :touch_resource
  after_save :index_observation
  after_destroy :index_observation, :touch_resource

  attr_accessor :skip_indexing, :bulk_delete

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

  def no_other_annotations_of_blocking_values
    return true unless controlled_attribute
    return true unless controlled_attribute.multivalued?
    scope = Annotation.
      where( controlled_attribute: controlled_attribute, resource: resource ).
      joins( :controlled_value ).
      where( "controlled_terms.blocking" )
    unless new_record?
      scope = scope.where( "annotations.id != ?", id )
    end
    if scope.count > 0
      errors.add( :controlled_value, "blocked by another value" )
    end
    true
  end

  def no_other_annotations_if_this_is_blocking
    return true unless controlled_attribute
    return true unless controlled_attribute.multivalued?
    return true unless controlled_value
    return true unless controlled_value.blocking?
    scope = Annotation.
      where( controlled_attribute: controlled_attribute, resource: resource )
    unless new_record?
      scope = scope.where( "id != ?", id )
    end
    if scope.count > 0
      errors.add( :controlled_value, "is blocking but another annotation already added" )
    end
    true
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
    index_observation unless bulk_delete
  end

  def as_indexed_json(options={})
    {
      uuid: uuid,
      controlled_attribute_id: controlled_attribute_id,
      controlled_value_id: controlled_value_id,
      concatenated_attr_val: [controlled_attribute_id, controlled_value_id].join("|"),
      vote_score: vote_score,
      user_id: user_id,
      votes: votes_for.map(&:as_indexed_json)
    }
  end

  def index_observation
    if resource.is_a?(Observation) && !skip_indexing && !bulk_delete
      Observation.elastic_index!(ids: [resource.id])
    end
    true
  end

  def index_observation_later
    if resource.is_a?(Observation) && !skip_indexing
      Observation.elastic_index!(ids: [resource.id], delay: true)
    end
  end

  def touch_resource
    resource.touch if resource && !(resource.bulk_delete || bulk_delete)
    true
  end

  def self.reassess_annotations_for_taxon_ids( taxon_ids )
    Annotation.
        joins(
          controlled_value: [
            { controlled_term_taxa: :taxon }
          ],
          controlled_attribute: {
            controlled_term_taxa: {
              taxon: :taxon_ancestors
            }
          }
        ).
        where( "taxon_ancestors.ancestor_taxon_id IN (?)", taxon_ids ).
        includes(
          { resource: :taxon },
          controlled_value: [
            :taxa,
            :excepted_taxa,
            { controlled_term_taxa: :taxon }
          ],
          controlled_attribute: [
            :values,
            :taxa,
            :excepted_taxa,
            { controlled_term_taxa: :taxon }
          ]
        ).
        find_each do |a|
      a.destroy unless a.valid?
    end
    
  end

  def self.reassess_annotations_for_attribute_id( attribute_id )
    Annotation.where( controlled_attribute_id: attribute_id ).find_each do |a|
      a.destroy unless a.valid?
    end
  end

end

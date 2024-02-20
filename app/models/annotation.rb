# frozen_string_literal: true

class Annotation < ApplicationRecord
  acts_as_votable
  blockable_by ->( annotation ) { annotation.resource.try( :user_id ) }

  # acts_as_votable automatically includes `has_subscribers` but
  # we don't want people to subscribe to annotations. Without this,
  # voting on annotations would invoke auto-subscription to the votable
  SUBSCRIBABLE = false

  belongs_to :controlled_attribute, class_name: "ControlledTerm"
  belongs_to :controlled_value, class_name: "ControlledTerm"
  belongs_to_with_uuid :resource, polymorphic: true
  belongs_to :user
  belongs_to :observation_field_value

  validates_presence_of :resource
  validates_presence_of :controlled_attribute
  # limiting the resource type to Observation to begin with
  validate :resource_is_an_annotatable
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

  after_commit :index_observation, on: [:create, :update, :destroy]
  after_commit :touch_resource, on: [:create, :destroy]

  attr_accessor :skip_indexing, :bulk_delete, :wait_for_obs_index_refresh

  def to_s
    "<Annotation #{id} user_id: #{user_id} resource_type: #{resource_type} resource_id: #{resource_id}>"
  end

  def resource_is_an_annotatable
    return if resource.is_a?( Observation ) || resource.is_a?( ObservedInteraction )

    errors.add( :resource_type, "must be an Observation or an ObservedInteraction" )
  end

  def attribute_is_an_attribute
    return if controlled_attribute && !controlled_attribute.is_value?

    errors.add( :controlled_attribute_id, "must be an attribute" )
  end

  def value_is_a_value
    return if controlled_value&.is_value?

    errors.add( :controlled_value_id, "must be a value" )
  end

  def value_belongs_to_attribute
    if controlled_value &&
        ( !controlled_attribute || !controlled_attribute.values.include?( controlled_value ) )
      errors.add( :controlled_value, "must belong to attribute" )
    end
  end

  def attribute_belongs_to_taxon
    return unless taxon && !controlled_attribute.applicable_to_taxon( taxon )

    errors.add( :controlled_attribute, "must belong to taxon" )
  end

  def value_belongs_to_taxon
    return unless controlled_value
    return unless taxon && !controlled_value.applicable_to_taxon( taxon )

    errors.add( :controlled_value, "must belong to taxon" )
  end

  def multiple_values
    return unless controlled_attribute
    return if controlled_attribute.multivalued?

    scope = Annotation.where( controlled_attribute: controlled_attribute,
      resource: resource )
    unless new_record?
      scope = scope.where( "id != ?", id )
    end
    return unless scope.count.positive?

    errors.add( :controlled_attribute, "cannot have multiple values" )
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
    if scope.count.positive?
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
    if scope.count.positive?
      errors.add( :controlled_value, "is blocking but another annotation already added" )
    end
    true
  end

  def taxon_id
    taxon.try( :id )
  end

  def taxon
    return resource.taxon if resource.is_a?( Observation )
    return resource.subject_observation.taxon if resource.is_a?( ObservedInteraction )
  end

  def vote_score
    if votes_for.loaded?
      votes_for.select( &:vote_flag? ).size -
        votes_for.reject( &:vote_flag? ).size
    else
      get_likes.size - get_dislikes.size
    end
  end

  def votable_callback
    index_observation unless bulk_delete
  end

  def as_indexed_json( _options = {} )
    {
      uuid: uuid,
      controlled_attribute_id: controlled_attribute_id,
      controlled_value_id: controlled_value_id,
      concatenated_attr_val: [controlled_attribute_id, controlled_value_id].join( "|" ),
      vote_score: vote_score,
      user_id: user_id,
      votes: votes_for.map( &:as_indexed_json )
    }
  end

  def index_observation
    if resource.is_a?( Observation ) && !skip_indexing && !bulk_delete
      Observation.elastic_index!( ids: [resource.id],
        wait_for_index_refresh: wait_for_obs_index_refresh )
    end
    true
  end

  def touch_resource
    if resource.respond_to?( :updated_at ) && !( resource.try( :bulk_delete ) || bulk_delete )
      resource.update_columns( updated_at: Time.now )
    end
    true
  end

  def controlled_attribute_label
    controlled_attribute.try( :label )
  end

  def controlled_value_label
    controlled_value.try( :label )
  end

  def deleteable_by?( target_user )
    return true if user == target_user
    return true if resource&.user == target_user

    false
  end

  def self.reassess_annotations_for_taxon_ids( taxon_ids )
    [taxon_ids].flatten.each do | taxon_id |
      Annotation.reassess_annotations_for_taxon_id( taxon_id )
    end
  end

  def self.reassess_annotations_for_taxon_id( taxon )
    taxon = Taxon.find_by_id( taxon ) unless taxon.is_a?( Taxon )
    Annotation.
      joins(
          controlled_attribute: {
            controlled_term_taxa: :taxon
          }
        ).
      where( taxon.subtree_conditions ).
      includes(
        { resource: :taxon },
        controlled_value: [
          :excepted_taxa,
          :taxa,
          :controlled_term_taxa
        ],
        controlled_attribute: [
          :excepted_taxa,
          :taxa,
          :controlled_term_taxa
        ]
      ).
      find_each do | a |
      # run the validation methods which might be affected by taxon changes
      a.attribute_belongs_to_taxon
      a.value_belongs_to_taxon
      # if any of them added errors, the annotation is no longer valid and should be destroyed
      a.destroy if a.errors.any?
    end
  end

  def self.reassess_annotations_for_attribute_id( attribute_id )
    Annotation.where( controlled_attribute_id: attribute_id ).find_each do | a |
      a.destroy unless a.valid?
    end
  end
end

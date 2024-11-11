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
  validate :resource_is_an_observation
  validate :attribute_is_an_attribute
  validate :value_is_a_value
  validate :value_belongs_to_attribute
  validate :validate_attribute_belongs_to_taxon
  validate :validate_value_belongs_to_taxon
  validate :multiple_values
  validate :no_other_annotations_of_blocking_values
  validate :no_other_annotations_if_this_is_blocking
  validates_uniqueness_of :controlled_value_id,
    scope: [:resource_type, :resource_id, :controlled_attribute_id]

  after_commit :index_observation, on: [:create, :update, :destroy]
  after_commit :touch_resource, on: [:create, :destroy]
  after_commit :update_user_counter_cache

  attr_accessor :skip_indexing, :bulk_delete, :wait_for_obs_index_refresh

  def to_s
    "<Annotation #{id} user_id: #{user_id} resource_type: #{resource_type} resource_id: #{resource_id}>"
  end

  def resource_is_an_observation
    return if resource.is_a?( Observation )

    errors.add( :resource_type, "must be an Observation" )
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
    return unless controlled_value && (
      !controlled_attribute || !controlled_attribute.values.include?( controlled_value ) )

    errors.add( :controlled_value, "must belong to attribute" )
  end

  def attribute_belongs_to_taxon?
    return true unless taxon && !controlled_attribute.applicable_to_taxon( taxon )

    false
  end

  def validate_attribute_belongs_to_taxon
    return if attribute_belongs_to_taxon?

    errors.add( :controlled_attribute, "must belong to taxon" )
  end

  def value_belongs_to_taxon?
    return true unless controlled_value
    return true unless taxon && !controlled_value.applicable_to_taxon( taxon )

    false
  end

  def validate_value_belongs_to_taxon
    return if value_belongs_to_taxon?

    errors.add( :controlled_value, "must belong to taxon" )
  end

  def taxon_mismatch_needs_updating?
    has_taxon_mismatch = !( attribute_belongs_to_taxon? && value_belongs_to_taxon? )
    # the annotation is not marked as a mismatch, but is now mismatched
    if has_taxon_mismatch && !term_taxon_mismatch
      return true
    end
    # the annotation is marked as a mismatch, but is now properly mismatched
    if !has_taxon_mismatch && term_taxon_mismatch
      return true
    end

    false
  end

  def multiple_values
    return unless controlled_attribute
    return if controlled_attribute.multivalued?

    scope = Annotation.where(
      controlled_attribute: controlled_attribute,
      resource: resource
    )
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
    return unless scope.count.positive?

    errors.add( :controlled_value, "blocked by another value" )
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
    return unless scope.count.positive?

    errors.add( :controlled_value, "is blocking but another annotation already added" )
  end

  def taxon_id
    taxon.try( :id )
  end

  def taxon
    return unless resource.is_a?( Observation )

    resource.taxon
  end

  def vote_score
    if votes_for.loaded?
      votes_for.select( &:vote_flag? ).size - votes_for.reject( &:vote_flag? ).size
    else
      get_likes.size - get_dislikes.size
    end
  end

  def votable_callback
    index_observation unless bulk_delete
  end

  def as_indexed_json
    {
      uuid: uuid,
      controlled_attribute_id: controlled_attribute_id,
      controlled_value_id: controlled_value_id,
      concatenated_attr_val: [controlled_attribute_id, controlled_value_id].join( "|" ),
      vote_score_short: vote_score,
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
    return unless resource.respond_to?( :updated_at ) &&
      !( resource.bulk_delete || bulk_delete ) &&
      resource.persisted?

    resource.update_columns( updated_at: Time.now )
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

  def update_user_counter_cache
    return unless user
    return if user.destroyed?
    return if bulk_delete

    User.delay(
      unique_hash: { "User::update_annotated_observations_counter_cache": user_id },
      run_at: 5.minutes.from_now
    ).update_annotated_observations_counter_cache( user_id )
  end

  def self.reassess_annotations_for_taxon_ids( taxon_ids )
    [taxon_ids].flatten.each do |taxon_id|
      Annotation.reassess_annotations_for_taxon_id( taxon_id )
    end
  end

  def self.reassess_annotations_for_taxon_id( taxon, options = {} )
    taxon = Taxon.find_by_id( taxon ) unless taxon.is_a?( Taxon )
    observation_ids_to_index = []
    scope = Annotation.joins(
      controlled_attribute: {
        controlled_term_taxa: :taxon
      }
    ).where( taxon.subtree_conditions )
    if options[:term_id]
      scope = scope.where(
        "controlled_attribute_id = ? OR controlled_value_id = ?",
        options[:term_id],
        options[:term_id]
      )
    end
    scope.includes(
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
    ).find_each do | a |
      if a.taxon_mismatch_needs_updating?
        a.update_columns( term_taxon_mismatch: !a.term_taxon_mismatch )
        observation_ids_to_index.push( a.resource_id ) if a.resource.is_a?( Observation )
      end
      # if there are more than 5000 observations that need to be indexed, queue
      # indexing in a delayed job and reset the array of obseravtions needing indexing
      if observation_ids_to_index.size >= 5_000
        Observation.elastic_index!( ids: observation_ids_to_index, delay: true, batch_size: 5_000 )
        observation_ids_to_index = []
      end
    end
    return unless observation_ids_to_index.any?

    # index any remaining affected observations
    Observation.elastic_index!( ids: observation_ids_to_index, delay: true, batch_size: 5_000 )
  end

  def self.reassess_annotations_for_term_id_and_taxon( term_id, taxon_id )
    reassess_annotations_for_taxon_id( taxon_id, term_id: term_id )
  end
end

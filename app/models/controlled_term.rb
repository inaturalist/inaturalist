#encoding: utf-8
class ControlledTerm < ApplicationRecord

  include ActsAsElasticModel
  # include ActsAsUUIDable
  before_validation :set_uuid
  def set_uuid
    self.uuid ||= SecureRandom.uuid
    self.uuid = uuid.downcase
    true
  end

  has_many :controlled_term_values, foreign_key: :controlled_attribute_id,
    class_name: "ControlledTermValue", dependent: :destroy
  has_many :controlled_term_value_attrs, foreign_key: :controlled_value_id,
    class_name: "ControlledTermValue", dependent: :destroy
  has_many :labels, class_name: "ControlledTermLabel", dependent: :destroy
  has_many :values, through: :controlled_term_values, source: :controlled_value
  has_many :attrs, through: :controlled_term_value_attrs, source: :controlled_attribute
  has_many :value_annotations, class_name: "Annotation", foreign_key: :controlled_value_id
  has_many :attribute_annotations, class_name: "Annotation", foreign_key: :controlled_attribute_id
  belongs_to :user
  has_many :controlled_term_taxa, inverse_of: :controlled_term, dependent: :destroy
  has_many :taxa,
    -> { where ["controlled_term_taxa.exception = ?", false] },
    through: :controlled_term_taxa
  has_many :excepted_taxa,
    -> { where ["controlled_term_taxa.exception = ?", true] },
    through: :controlled_term_taxa,
    source: :taxon

  validates_associated :labels
  validates :labels, presence: true

  after_commit :index_attributes
  scope :active, -> { where(active: true) }
  scope :attributes, -> { where(is_value: false) }
  scope :unassigned_values, -> {
    where(is_value: true).
    joins("LEFT JOIN controlled_term_values ctv ON (controlled_terms.id = ctv.controlled_value_id)").
    where("ctv.id IS NULL")
  }
  scope :for_taxon, -> (taxon) {
    joins( "LEFT OUTER JOIN controlled_term_taxa ctt ON ctt.controlled_term_id = controlled_terms.id" ).
    where( "ctt.id IS NULL OR ctt.taxon_id IN (?)", taxon.path_ids ).distinct
  }

  accepts_nested_attributes_for :controlled_term_taxa, allow_destroy: true

  VALUES_TO_MIGRATE = {
    male: :sex,
    female: :sex,
    juvenile: :life_stage,
    adult: :life_stage,
    pupa: :life_stage,
    pupae: :life_stage,
    larva: :life_stage,
    larvae: :life_stage,
    caterpillar: :life_stage,
    teneral: :life_stage,
    egg: :life_stage,
    nymph: :life_stage,
    track: :evidence_of_presence,
    scat: :evidence_of_presence,
    bone: :evidence_of_presence,
    feather: :evidence_of_presence,
    molt: :evidence_of_presence
  }

  attr_accessor :prepared_values

  def to_s
    "<ControlledTerm #{id}: #{labels.first.try(:name)}>"
  end

  def self.first_term_by_label(label)
    return unless label
    first_label = ControlledTermLabel.
      where("lower(label) = ?", label.downcase).first
    return first_label.controlled_term if first_label
  end

  def self.life_stage
    @@life_stage ||= ControlledTermLabel.
      where("lower(label) = 'life stage'").first.controlled_term
  end

  def term_label(options = { })
    options[:locale] = options[:locale].to_s || "en"
    all_labels = labels.sort_by(&:id)
    if options[:taxon] && options[:taxon].is_a?(Taxon)
      if match = all_labels.detect{ |l| l.locale == options[:locale] &&
          l.valid_within_taxon && options[:taxon].has_ancestor_taxon_id(l.valid_within_taxon.id) }
        return match
      end
    end
    if match = all_labels.detect{ |l| l.locale == options[:locale] }
      return match
    end
    all_labels.first
  end

  def label(options = { })
    if tl = term_label(options)
      tl.label
    end
  end

  def possible_attribute_associates
    return unless is_value?
    scope = ControlledTerm.attributes
    if controlled_term_value_attrs.any?
      scope = scope.where("id NOT IN (?)", controlled_term_value_attrs.map(&:controlled_attribute_id))
    end
    scope.map{ |t| [ t.label, t.id ] }
  end

  def values_for_observation(o)
    values - o.annotations.where(controlled_attribute: self).map{ |ct| ct.controlled_value }
  end

  def applicable_to_taxon( candidate_taxon )
    return false if candidate_taxon.blank? || !candidate_taxon.is_a?(Taxon)
    return true if controlled_term_taxa.blank?
    return false if excepted_taxa.detect{ |taxon| candidate_taxon.has_ancestor_taxon_id( taxon.id ) }
    return true if taxa.blank? || taxa.detect{ |taxon| candidate_taxon.has_ancestor_taxon_id( taxon.id ) }
    false
  end

  def index_attributes
    return true unless attrs.exists?
    ControlledTerm.elastic_index!( ids: attr_ids )
    true
  end

end

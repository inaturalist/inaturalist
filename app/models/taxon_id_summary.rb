# frozen_string_literal: true

class TaxonIdSummary < ApplicationRecord
  include ActsAsUUIDable
  has_many :id_summaries, dependent: :destroy

  validates :taxon_id, presence: true
  validates :taxon_name, presence: true
  validates :language, presence: true
  validate :single_active_run

  scope :active, -> { where( active: true ) }

  private

  def single_active_run
    return unless active?
    return unless taxon_id.present?
    scope = TaxonIdSummary.where( taxon_id: taxon_id, active: true )
    scope = scope.where( language: language ) if language.present?
    return unless scope.where.not( id: id ).exists?

    errors.add( :active, "only one active taxon_id_summary is allowed per language" )
  end
end

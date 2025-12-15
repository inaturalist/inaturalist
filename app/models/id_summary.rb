# frozen_string_literal: true

class IdSummary < ApplicationRecord
  acts_as_flaggable

  belongs_to :taxon_id_summary

  has_many :id_summary_references, dependent: :destroy
  has_many :id_summary_dqas, dependent: :destroy

  validates_presence_of :taxon_id_summary
end

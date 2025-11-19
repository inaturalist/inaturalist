# frozen_string_literal: true

class IdSummaryReference < ApplicationRecord
  belongs_to :id_summary

  has_many :id_summary_reference_dqas, dependent: :destroy

  validates_presence_of :id_summary
end

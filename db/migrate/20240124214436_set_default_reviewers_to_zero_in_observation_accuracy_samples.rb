# frozen_string_literal: true

class SetDefaultReviewersToZeroInObservationAccuracySamples < ActiveRecord::Migration[6.1]
  def change
    change_column_default( :observation_accuracy_samples, :reviewers, from: nil, to: 0 )
  end
end

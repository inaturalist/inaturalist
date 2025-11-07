# frozen_string_literal: true

class AddPhotoTipToIdSummaries < ActiveRecord::Migration[6.1]
  def change
    add_column :id_summaries, :photo_tip, :string
  end
end


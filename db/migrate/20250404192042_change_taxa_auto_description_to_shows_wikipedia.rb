# frozen_string_literal: true

class ChangeTaxaAutoDescriptionToShowsWikipedia < ActiveRecord::Migration[6.1]
  def change
    rename_column :taxa, "auto_description", "shows_wikipedia"
  end
end

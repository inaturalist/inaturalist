# frozen_string_literal: true

class AddProvisionalToTaxa < ActiveRecord::Migration[6.1]
  def change
    add_column :taxa, :provisional, :boolean, default: false, null: false
  end
end

class AddIndexOnRulerIdAndRulerTypeToRules < ActiveRecord::Migration[6.1]
  def change
    add_index :rules, [:ruler_id, :ruler_type]
  end
end

class CreateRules < ActiveRecord::Migration
  def self.up
    create_table :rules do |t|
      t.string :type
      t.string :ruler_type
      t.integer :ruler_id
      t.string :operand_type
      t.integer :operand_id
      t.string :operator

      t.timestamps
    end
  end

  def self.down
    drop_table :rules
  end
end

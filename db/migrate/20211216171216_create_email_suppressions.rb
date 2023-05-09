class CreateEmailSuppressions < ActiveRecord::Migration[5.2]
  def change
    create_table :email_suppressions do | t |
      t.text :email
      t.text :suppression_type
      t.timestamps
    end
    add_index :email_suppressions, [:email, :suppression_type]
  end
end

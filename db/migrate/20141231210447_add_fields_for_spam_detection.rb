class AddFieldsForSpamDetection < ActiveRecord::Migration
  def change
    add_column :users, :spammer, :boolean
    add_column :users, :spam_count, :integer, default: 0
    add_index :users, :spammer
  end
end

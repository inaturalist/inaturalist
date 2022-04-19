class AddUserIdToEmailSuppressions < ActiveRecord::Migration[6.1]
  def change
    add_column :email_suppressions, :user_id, :integer
    add_index :email_suppressions, :user_id
  end
end

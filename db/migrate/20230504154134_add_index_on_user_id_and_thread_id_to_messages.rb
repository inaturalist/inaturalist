class AddIndexOnUserIdAndThreadIdToMessages < ActiveRecord::Migration[6.1]
  def change
    add_index :messages, [:user_id, :thread_id]
  end
end

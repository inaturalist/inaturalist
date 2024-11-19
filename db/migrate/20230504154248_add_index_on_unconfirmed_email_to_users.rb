class AddIndexOnUnconfirmedEmailToUsers < ActiveRecord::Migration[6.1]
  def change
    add_index :users, [:unconfirmed_email]
  end
end

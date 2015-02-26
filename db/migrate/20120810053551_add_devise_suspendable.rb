class AddDeviseSuspendable < ActiveRecord::Migration
  def up
    add_column :users, :suspended_at, :datetime
    add_column :users, :suspension_reason, :string
    User.where(state: "suspended").update_all(suspended_at: Time.now)
  end

  def down
    remove_column :users, :suspended_at
    remove_column :users, :suspension_reason
  end
end

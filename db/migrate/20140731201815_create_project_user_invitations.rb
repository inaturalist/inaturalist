class CreateProjectUserInvitations < ActiveRecord::Migration
  def change
    create_table :project_user_invitations do |t|
      t.integer :user_id
      t.integer :invited_user_id
      t.integer :project_id
      t.timestamps
    end
    add_index :project_user_invitations, :user_id
    add_index :project_user_invitations, :invited_user_id
    add_index :project_user_invitations, :project_id
  end
end

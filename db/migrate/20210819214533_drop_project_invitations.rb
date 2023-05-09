class DropProjectInvitations < ActiveRecord::Migration[5.2]
  def up
    drop_table :project_invitations if table_exists? :project_invitations
  end

  def down
    create_table :project_invitations do |t|
      t.integer :project_id
      t.integer :user_id
      t.integer :observation_id

      t.timestamps
    end
    add_index :project_invitations, :observation_id
  end
end

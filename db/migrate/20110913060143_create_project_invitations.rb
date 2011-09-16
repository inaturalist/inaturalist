class CreateProjectInvitations < ActiveRecord::Migration
  def self.up
    create_table :project_invitations do |t|
       t.integer :project_id
       t.integer :user_id
       t.integer :observation_id
       
       t.timestamps
    end
    add_index :project_invitations, :observation_id
  end

  def self.down
    drop_table :project_invitations
  end
end

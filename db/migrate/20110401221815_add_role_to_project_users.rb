class AddRoleToProjectUsers < ActiveRecord::Migration
  def self.up
    add_column :project_users, :role, :string
    ProjectUser.all.each do |project_user|
      if project_user.user_id == project_user.project.user_id
        project_user.role = 'curator'
        project_user.save
      end
    end
  end

  def self.down
    remove_column :project_users, :role
  end
  
end

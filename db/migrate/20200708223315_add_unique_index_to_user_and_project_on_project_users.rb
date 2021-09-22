class AddUniqueIndexToUserAndProjectOnProjectUsers < ActiveRecord::Migration
  def change
    # Remove existing duplicate ProjectUsers, prioritizing ones with roles
    rows = ActiveRecord::Base.connection.execute( "
      SELECT project_id, user_id
      FROM project_users
      GROUP BY project_id, user_id
      HAVING count(*) > 1
      ORDER BY count(*) desc"
    )
    rows.each do |r|
      ProjectUser.where( project_id: r["project_id"], user_id: r["user_id"] ).
        order( "LENGTH(role) desc NULLS LAST, created_at asc" ).each_with_index do |pu, index|
        next if index == 0
        pu.destroy
      end
    end
    add_index :project_users, [:user_id, :project_id], unique: true
  end

  def down
    drop_index :project_users, [:user_id, :project_id]
  end
end

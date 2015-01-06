class CreateGuideUsers < ActiveRecord::Migration
  def change
    create_table :guide_users do |t|
      t.integer :guide_id
      t.integer :user_id
      t.timestamps
    end
    add_index :guide_users, :guide_id
    add_index :guide_users, :user_id
    Guide.find_each do |g|
      GuideUser.create(:guide_id => g.id, :user_id => g.user_id)
    end
  end
end

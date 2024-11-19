class CreateUserDailyActiveCategory < ActiveRecord::Migration[6.1]
  def change
    create_table :user_daily_active_categories do |t|
      t.integer :user_id
      t.string :today_category
      t.string :yesterday_category
      t.timestamps
    end

    add_index :user_daily_active_categories, :user_id, unique: true
    add_index :user_daily_active_categories, [:today_category, :yesterday_category], :name => "index_udac_on_tc_yc"
  end
end

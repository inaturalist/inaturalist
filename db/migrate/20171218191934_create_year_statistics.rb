class CreateYearStatistics < ActiveRecord::Migration
  def change
    create_table :year_statistics do |t|
      t.integer :user_id
      t.integer :year
      t.json :data
      t.timestamps
    end
    add_index :year_statistics, :user_id
  end
end

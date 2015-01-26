class AddDenormalizedWindshaftTables < ActiveRecord::Migration
  def up
    WindshaftDenormalizer.create_all_tables
  end

  def down
    WindshaftDenormalizer.destroy_all_tables
  end
end

class AddDistanceAndNumberToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :distance, :float, null: true
    add_column :posts, :number, :integer, null: true
  end
end

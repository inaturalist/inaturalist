class AddDistanceAndNumberToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :distance, :float
    add_column :posts, :number, :integer
  end
end

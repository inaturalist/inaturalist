class AddBlurhashToPhotos < ActiveRecord::Migration[6.1]
  def up
    add_column :photos, :blurhash, :string
  end

  def down
    remove_column :photos, :blurhash
  end
end

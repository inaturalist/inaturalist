# frozen_string_literal: true

class CreateBlogV2TablesAndPostColumns < ActiveRecord::Migration[6.1]
  def change
    create_table :blog_categories do | t |
      t.integer :site_id, null: false
      t.string :slug, null: false
      t.string :label, null: false
      t.integer :position
      t.timestamps
    end
    add_index :blog_categories, [:site_id, :slug], unique: true

    create_table :post_images do | t |
      t.integer :user_id, null: false
      t.integer :post_id
      t.attachment :file
      t.integer :width
      t.integer :height
      t.text :caption
      t.text :attribution
      t.text :alt
      t.datetime :created_at, null: false
    end
    add_index :post_images, :post_id
    add_index :post_images, [:user_id, :created_at]

    add_column :posts, :cover_image_id, :bigint
    add_column :posts, :featured_at, :datetime
    add_column :posts, :mobile_featured_at, :datetime
    add_column :posts, :locale, :string
    add_column :posts, :blog_category_id, :bigint
    add_foreign_key :posts, :blog_categories, on_delete: :restrict, validate: false
  end
end

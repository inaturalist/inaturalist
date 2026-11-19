# frozen_string_literal: true

class AddBlogV2PostIndexes < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    validate_foreign_key :posts, :blog_categories
    add_index :posts, [:parent_type, :parent_id, :published_at], algorithm: :concurrently
    add_index :posts, :blog_category_id, algorithm: :concurrently
    add_index :posts, [:parent_id, :featured_at],
      order: { featured_at: :desc },
      where: "parent_type = 'Site' AND featured_at IS NOT NULL",
      name: "index_posts_on_site_featured",
      algorithm: :concurrently
    add_index :posts, [:parent_id, :mobile_featured_at],
      order: { mobile_featured_at: :desc },
      where: "parent_type = 'Site' AND mobile_featured_at IS NOT NULL",
      name: "index_posts_on_site_mobile_featured",
      algorithm: :concurrently
  end

  def down
    remove_index :posts, name: "index_posts_on_site_mobile_featured", algorithm: :concurrently
    remove_index :posts, name: "index_posts_on_site_featured", algorithm: :concurrently
    remove_index :posts, :blog_category_id, algorithm: :concurrently
    remove_index :posts, [:parent_type, :parent_id, :published_at], algorithm: :concurrently
  end
end

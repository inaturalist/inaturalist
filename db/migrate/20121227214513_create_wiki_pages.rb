class CreateWikiPages < ActiveRecord::Migration

  def self.up
    create_table :wiki_pages do |t|
      t.integer :creator_id
      t.integer :updator_id

      t.string :path
      t.string :title

      t.text :content

      t.timestamps
    end

    add_index :wiki_pages, :creator_id
    add_index :wiki_pages, :path, :unique => true

    create_table :wiki_page_versions do |t|
      t.integer :page_id, :null => false # Reference to page
      t.integer :updator_id # Reference to user, updated page

      t.integer :number # Version number

      t.string :comment

      t.string :path
      t.string :title

      t.text :content

      t.timestamp :updated_at
    end

    add_index :wiki_page_versions, :page_id
    add_index :wiki_page_versions, :updator_id
  end

  def self.down
    drop_table :wiki_page_versions
    drop_table :wiki_pages
  end

end

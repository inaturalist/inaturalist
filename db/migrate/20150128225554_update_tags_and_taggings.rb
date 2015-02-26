class UpdateTagsAndTaggings < ActiveRecord::Migration
  def up
    # This will ensure Tag.name is unique
    # fetch the tag names that exist more than once
    ActsAsTaggableOn::Tag.group(:name).select(:name).
      having("count(*) > 1").map(&:name).each do |duplicate_tag|
      # get the first tag with this name
      first_tag = ActsAsTaggableOn::Tag.where(name: duplicate_tag).first
      # update all taggings to use the tag_id for this tag name
      ActsAsTaggableOn::Tagging.joins(:tag).where("tags.name = ?", duplicate_tag).
        update_all(tag_id: first_tag.id)
      # delete all subsequent tags with this name
      ActsAsTaggableOn::Tag.where(name: duplicate_tag).where("id != ?", first_tag.id).delete_all
    end

    add_index :tags, :name, unique: true
    add_column :tags, :taggings_count, :integer, default: 0

    change_table :taggings do |t|
      t.references :tagger, polymorphic: true
      t.string :context, limit: 128
    end

    remove_index :taggings, :tag_id
    remove_index :taggings, [ :taggable_id, :taggable_type ]

    add_index :taggings,
              [ :tag_id, :taggable_id, :taggable_type, :context, :tagger_id, :tagger_type ],
              unique: true, name: "taggings_idx"
    add_index :taggings, [ :taggable_id, :taggable_type, :context ]
  end

  def down
    remove_index :taggings, [ :taggable_id, :taggable_type, :context ]
    remove_index :taggings, name: "taggings_idx"

    add_index :taggings, :tag_id
    add_index :taggings, [ :taggable_id, :taggable_type ]

    remove_column :taggings, :context
    remove_column :taggings, :tagger_id
    remove_column :taggings, :tagger_type

    remove_column :tags, :taggings_count
    remove_index :tags, :name
  end
end

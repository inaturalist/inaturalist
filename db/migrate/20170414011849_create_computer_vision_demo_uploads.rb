class CreateComputerVisionDemoUploads < ActiveRecord::Migration
  def change
    create_table :computer_vision_demo_uploads do |t|
      t.uuid :uuid, default: "uuid_generate_v4()"
      t.string :photo_file_name
      t.string :photo_content_type
      t.string :photo_file_size
      t.string :photo_updated_at
      t.string :original_url
      t.string :thumbnail_url
      t.boolean :mobile
      t.string :user_agent
      t.text :metadata
      t.timestamps
    end

    add_index :computer_vision_demo_uploads, :uuid
  end
end

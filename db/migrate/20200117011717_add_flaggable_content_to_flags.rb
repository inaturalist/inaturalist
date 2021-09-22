class AddFlaggableContentToFlags < ActiveRecord::Migration
  def change
    add_column :flags, :flaggable_content, :text
  end
end

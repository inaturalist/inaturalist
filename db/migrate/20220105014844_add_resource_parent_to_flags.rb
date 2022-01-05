class AddResourceParentToFlags < ActiveRecord::Migration[5.2]
  def change
    change_table :flags do |f|
      f.references :flaggable_parent, polymorphic: true
    end
  end
end

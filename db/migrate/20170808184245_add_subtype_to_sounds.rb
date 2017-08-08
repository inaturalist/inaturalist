class AddSubtypeToSounds < ActiveRecord::Migration
  def change
    add_column :sounds, :subtype, :string, limit: 255
  end
end

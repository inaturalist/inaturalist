class UpdateLifeListsAsLists < ActiveRecord::Migration
  def up
    execute "UPDATE lists SET type = NULL WHERE type = 'LifeList'"
  end

  def down
    # Cannot undo this
  end
end

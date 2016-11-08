class CreateIdsIndex < ActiveRecord::Migration
  def up
    Identification.__elasticsearch__.create_index! force: true
  end

  def down
    # not deleting the indices on down. If you redo this migration
    # the up method with destory and recreate your indices
  end
end

class CreateUpdatesIndex < ActiveRecord::Migration
  def up
    # delete older updates
    starting_id = Update.where("created_at >= '2014-11-01'").minimum("id")
    Update.where("id < #{ starting_id }").delete_all
    Update.__elasticsearch__.create_index! force: true
  end

  def down
    # not deleting the indices on down. If you redo this migration
    # the up method with destory and recreate your indices
  end
end

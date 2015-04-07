class CreateElasticsearchIndices < ActiveRecord::Migration
  def up
    Observation.__elasticsearch__.create_index! force: true
    Place.__elasticsearch__.create_index! force: true
    Project.__elasticsearch__.create_index! force: true
    Taxon.__elasticsearch__.create_index! force: true
  end

  def down
    # not deleting the indices on down. If you redo this migration
    # the up method with destory and recreate your indices
  end
end

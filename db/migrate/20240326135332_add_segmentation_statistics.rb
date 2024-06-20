class AddSegmentationStatistics < ActiveRecord::Migration[6.1]
  def change
    create_table :segmentation_statistics do |t|
      t.datetime :created_at
      t.json :data
    end
  end
end

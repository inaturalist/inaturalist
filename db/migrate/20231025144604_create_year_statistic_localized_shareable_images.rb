class CreateYearStatisticLocalizedShareableImages < ActiveRecord::Migration[6.1]
  def change
    create_table :year_statistic_localized_shareable_images do |t|
      t.integer :year_statistic_id, null: false
      t.string :locale, null: false
      t.attachment :shareable_image
      t.timestamps
    end

    # giving this index a custom name as the auto-generated name is too long
    add_index :year_statistic_localized_shareable_images, :year_statistic_id,
      name: "index_year_statistic_localized_shareable_images_on_ys_id"
  end
end

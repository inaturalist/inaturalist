class CreateDataPartners < ActiveRecord::Migration
  def change
    create_table :data_partners do |t|
      t.string :name
      t.string :url
      t.string :partnership_url
      t.string :frequency
      t.json :dwca_params
      t.timestamp :dwca_last_export_at
      t.string :api_request_url
      t.text :description
      t.text :requirements
      t.timestamp :last_sync_observation_links_at

      t.timestamps null: false
    end
  end
end

class CreateApiEndpoints < ActiveRecord::Migration
  def change
    create_table :api_endpoints do |t|
      t.string :title, null: false, index: true
      t.text :description
      t.string :documentation_url
      t.string :base_url
      t.integer :cache_hours
      t.timestamps
    end

    create_table :api_endpoint_caches do |t|
      t.references :api_endpoint, index: true
      t.string :request_url, index: true
      t.timestamp :request_began_at
      t.timestamp :request_completed_at
      t.boolean :success
      t.text :response
      t.timestamps
    end
  end
end

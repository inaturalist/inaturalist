class AddThrottledAtToApiEndpointCaches < ActiveRecord::Migration[6.1]
  def change
    add_column :api_endpoint_caches, :throttled_at, :datetime
  end
end

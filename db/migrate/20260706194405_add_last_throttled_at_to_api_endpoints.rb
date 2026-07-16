class AddLastThrottledAtToApiEndpoints < ActiveRecord::Migration[6.1]
  def change
    add_column :api_endpoints, :last_throttled_at, :datetime
  end
end

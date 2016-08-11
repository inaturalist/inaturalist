class Update < ActiveRecord::Base
  include ActsAsElasticModel
end

class RemoveUpdatesIndex < ActiveRecord::Migration
  def up
    Update.__elasticsearch__.delete_index!
  end

  def down
    Update.__elasticsearch__.create_index!(force: true)
  end
end

class Update < ActiveRecord::Base
  include ActsAsElasticModel
end

class RemoveUpdatesIndex < ActiveRecord::Migration
  def up
    begin
      Update.__elasticsearch__.delete_index!
    rescue StandardError => e
      raise e unless e.message =~ /index_not_found_exception/
      # index_not_found_exception is ok, just means it doesn't exist so no need to delete.
    end
  end

  def down
    Update.__elasticsearch__.create_index!(force: true)
  end
end

class CleanExtraneousVisionPreferences < ActiveRecord::Migration
  def up
    execute "DELETE FROM preferences WHERE owner_type = 'Identification' and name = 'vision' and value is null"
  end

  def down
    say "Can't be undone"
  end
end

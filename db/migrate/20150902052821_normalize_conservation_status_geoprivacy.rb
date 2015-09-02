class NormalizeConservationStatusGeoprivacy < ActiveRecord::Migration
  def up
    execute <<-SQL
      UPDATE conservation_statuses SET geoprivacy = NULL WHERE geoprivacy = ''
    SQL
  end
  def down
    say "THERE IS NO GOING BACK!!"
  end
end

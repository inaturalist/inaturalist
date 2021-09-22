class RemoveSameDayObscurationPreferences < ActiveRecord::Migration
  def up
    execute "DELETE FROM preferences WHERE name in ('auto_obscuration', 'coordinate_interpolation_protection', 'coordinate_interpolation_protection_test')"
  end

  def down
    # Cannot undo this
  end
end

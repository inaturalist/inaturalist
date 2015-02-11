class SwitchPreferences < ActiveRecord::Migration
  def self.up
    rename_column :users, :preferences, :old_preferences
    User.where("old_preferences IS NOT NULL").find_each do |u|
      next if u.old_preferences.blank?
      old_prefs = Hash[u.old_preferences[/Preferences \n(.*)/m, 1].split("\n").map{|t| t.split(": ")}]
      old_prefs.each do |pref, value|
        new_value = if value == "true"
          true
        elsif value == "false"
          false
        elsif value.to_i > 0
          value.to_i
        else
          value
        end
        u.write_preference(pref, new_value) unless new_value.blank?
      end
      u.save(false)
    end
  end

  def self.down
    rename_column :users, :old_preferences, :preferences
  end
end

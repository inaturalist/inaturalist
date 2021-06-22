class RemoveEmailPreferencesFromSites < ActiveRecord::Migration
  def up
    # Doing it in this silly way because there's no index on owner_type in the
    # preferences table
    Site.all.each do |site|
      %w{email_admin email_info}.each do |pref_name|
        say "Removing #{pref_name} for #{site}"
        Preference.where( owner: site, name: pref_name ).delete_all
      end
    end
  end

  def down
    say "No going back from this"
  end
end

class RemoveSiteOnlyObservationsFromSites < ActiveRecord::Migration
  def up
    Preference.where(owner_type: 'Site', name: 'site_only_observations', value: 't').update_all("name = 'site_observations_filter', value = 'site'")
    Preference.where(owner_type: 'Site', name: 'site_only_observations', value: 'f').delete_all
  end
  def down
    Preference.where(owner_type: 'Site', name: 'site_observations_filter', value: 'site').update_all("name = 'site_only_observations', value = 't'")
  end
end

class AddToSites < ActiveRecord::Migration
  def change
    add_column :sites, :domain, :string
    add_column :sites, :coordinate_systems_json, :text
    Preference.where(name: ['taxon_describers','name_providers','flickr_key',
      'flickr_shared_secret','facebook_app_id','ubio_key','yahoo_developers_network_app_id',
      'facebook_app_secret','facebook_admin_ids','facebook_namespace','twitter_key',
      'twitter_secret','cloudmade_key','bing_key','soundcloud_client_id',
      'soundcloud_secret','natureserve_key'] ).destroy_all
  end
end

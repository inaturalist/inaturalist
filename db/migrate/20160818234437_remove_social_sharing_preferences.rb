class RemoveSocialSharingPreferences < ActiveRecord::Migration
  def up
    execute "DELETE FROM preferences WHERE name IN ('share_observations_on_twitter', 'share_observations_on_facebook')"
  end

  def down
    say "There's no coming back from this"
  end
end

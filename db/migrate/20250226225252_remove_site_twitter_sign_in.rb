# frozen_string_literal: true

class RemoveSiteTwitterSignIn < ActiveRecord::Migration[6.1]
  def up
    # Remove site preference for twitter sign in
    execute "DELETE FROM preferences WHERE owner_type = 'Site' AND name = 'twitter_sign_in'"

    # Remove potentially private data from twitter
    execute <<-SQL
      UPDATE provider_authorizations
      SET token = null, secret = null, refresh_token = null
      WHERE provider_name = 'twitter'
    SQL

    # Need to make sure the cached site is cleared too or the app won't start
    Rails.cache.delete( "sites_default" )
  end

  def down
    say "No reverting this change"
  end
end

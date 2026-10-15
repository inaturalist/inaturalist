# frozen_string_literal: true

require "action_dispatch/session/active_record_store"

# Be sure to restart your server when you modify this file.

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# Inaturalist::Application.config.session_store :active_record_store

Inaturalist::Application.config.session_store(
  :active_record_store,
  key: SiteConfig.rails.session_key
)

module AsyncCommitActiveRecordSessionSaves
  def save( *args, **kwargs, & )
    connection = self.class.connection

    # Avoid changing the durability of a larger transaction belonging
    # to application code.
    return super if connection.transaction_open?

    self.class.transaction do
      connection.execute( "SET LOCAL synchronous_commit = off" )
      super
    end
  end
end

Rails.application.config.after_initialize do
  session_class = ActionDispatch::Session::ActiveRecordStore.session_class

  unless session_class.ancestors.include?( AsyncCommitActiveRecordSessionSaves )
    session_class.prepend( AsyncCommitActiveRecordSessionSaves )
  end
end

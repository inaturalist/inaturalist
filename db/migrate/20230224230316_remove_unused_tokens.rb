# frozen_string_literal: true

class RemoveUnusedTokens < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE provider_authorizations
      SET token = NULL, refresh_token = NULL, secret = NULL
      WHERE provider_name IN ('twitter', 'open_id', 'orcid', 'apple', 'facebook')
    SQL
  end

  def down
    say "Cannot restore deleted tokens"
  end
end

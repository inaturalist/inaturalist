class NullifyUsersConfirmationSentAt < ActiveRecord::Migration[6.1]
  def up
    say "You might want to perform this nullification before running this migration if there are a lot of users"
    execute <<~SQL
      UPDATE users
      SET confirmation_token = NULL, confirmation_sent_at = NULL, confirmed_at = NULL
      WHERE
        confirmation_token IS NOT NULL
        OR confirmation_sent_at IS NOT NULL
        OR confirmed_at IS NOT NULL
    SQL
  end

  def down
    say "No coming back from this"
  end
end

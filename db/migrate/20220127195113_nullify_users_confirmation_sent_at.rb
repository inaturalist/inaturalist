class NullifyUsersConfirmationSentAt < ActiveRecord::Migration[6.1]
  def up
    execute "UPDATE users SET confirmation_sent_at = NULL, confirmed_at = NULL"
  end

  def down
    say "No coming back from this"
  end
end

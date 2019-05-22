class AddPiConsentAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :pi_consent_at, :datetime
  end
end

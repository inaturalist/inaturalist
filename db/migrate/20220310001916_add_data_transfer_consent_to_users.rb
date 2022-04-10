class AddDataTransferConsentToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :data_transfer_consent_at, :datetime
  end
end

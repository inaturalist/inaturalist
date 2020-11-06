class AddIndexOnProviderAuthorizationsNameAndUid < ActiveRecord::Migration
  def change
    add_index :provider_authorizations, [:provider_name, :provider_uid]
  end
end

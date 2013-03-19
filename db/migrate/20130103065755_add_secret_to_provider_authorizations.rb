class AddSecretToProviderAuthorizations < ActiveRecord::Migration
  def change
    add_column :provider_authorizations, :secret, :string
  end
end

class AddRefreshTokenToProviderAuthorizations < ActiveRecord::Migration
  def change
    add_column :provider_authorizations, :refresh_token, :string
  end
end

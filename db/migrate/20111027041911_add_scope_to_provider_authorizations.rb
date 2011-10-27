class AddScopeToProviderAuthorizations < ActiveRecord::Migration
  def self.up
    add_column :provider_authorizations, :scope, :string
  end

  def self.down
    remove_column :provider_authorizations, :scope
  end
end

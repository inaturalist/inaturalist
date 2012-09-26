class AddSecretToFlickrIdentities < ActiveRecord::Migration
  def change
    add_column :flickr_identities, :secret, :string
  end
end

class AddDonorVerifiedColumns < ActiveRecord::Migration
  def change
    add_column :users, :donorbox_donor_id, :integer
    add_column :user_parents, :donorbox_donor_id, :integer
  end
end

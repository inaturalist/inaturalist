# frozen_string_literal: true

class AddVirtuousDonorColumns < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :virtuous_donor_contact_id, :integer
    add_column :user_parents, :virtuous_donor_contact_id, :integer
  end
end

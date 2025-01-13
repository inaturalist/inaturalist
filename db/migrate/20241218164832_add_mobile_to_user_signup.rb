# frozen_string_literal: true

class AddMobileToUserSignup < ActiveRecord::Migration[6.1]
  def change
    add_column :user_signups, :mobile, :boolean, default: false
  end
end

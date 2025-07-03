# frozen_string_literal: true

class AddFundraiseupPlanColumnsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :fundraiseup_supporter_id, :string
    add_column :users, :fundraiseup_plan_frequency, :string
    add_column :users, :fundraiseup_plan_status, :string
    add_column :users, :fundraiseup_plan_started_at, :date
    add_column :user_parents, :fundraiseup_supporter_id, :string
  end
end

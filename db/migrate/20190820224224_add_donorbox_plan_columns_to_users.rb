class AddDonorboxPlanColumnsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :donorbox_plan_type, :string
    add_column :users, :donorbox_plan_status, :string
    add_column :users, :donorbox_plan_started_at, :date
  end
end

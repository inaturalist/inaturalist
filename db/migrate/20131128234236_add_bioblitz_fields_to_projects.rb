class AddBioblitzFieldsToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :event_url, :string
    add_column :projects, :start_time, :datetime
    add_column :projects, :end_time, :datetime
  end
end

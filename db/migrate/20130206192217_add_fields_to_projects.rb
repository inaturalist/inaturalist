class AddFieldsToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :place_id, :integer
    add_column :projects, :map_type, :string, :default => "terrain"
    add_column :projects, :latitude, :decimal, :precision => 15, :scale => 10
    add_column :projects, :longitude, :decimal, :precision => 15, :scale => 10
    add_column :projects, :zoom_level, :integer

    add_index :projects, :place_id

    Project.includes(:project_observation_rules).where("rules.operator = 'observed_in_place?'").find_each do |p|
      next unless (place = p.rule_place)
      p.update_attributes(
        :place => place, 
        :latitude => place.latitude, 
        :longitude => place.longitude
      )
    end
  end
end

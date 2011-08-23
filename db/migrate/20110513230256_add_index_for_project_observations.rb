class AddIndexForProjectObservations < ActiveRecord::Migration
  def self.up
    add_index :project_observations, :curator_identification_id
    ProjectObservation.find_each(:include => {:observation => :identifications}) do |po|
     po.observation.identifications.each do |ident|
       Identification.run_update_curator_identification(ident)
     end
    end
  end
  
  def self.down
    remove_index :project_observations, :curator_identification_id
  end
end

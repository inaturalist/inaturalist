class DropMarkings < ActiveRecord::Migration
  def self.up
    drop_table "markings"
    drop_table "marking_types"
  end

  def self.down
    create_table :marking_types do |t|
      t.string      :name
      t.timestamps
    end
    
    puts "Creating the first set of markings."
    ['Beautiful',
     'Bizzare',
     'Crikey!',
     'Cute',
     'Dangerous',
     'Rare'].each do |marking|
       puts "Creating marking type: %s." % marking
       MarkingType.create({
         :name => marking
       })
     end
     
     create_table :markings do |t|
       t.integer       :user_id
       t.integer       :observation_id
       t.integer       :marking_type_id
       t.timestamps
     end
  end
end

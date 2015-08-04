class ChangeDefaultQualityGrade < ActiveRecord::Migration
  def up
    change_column :observations, :quality_grade, :string, default: 'unverifiable', limit: 128
    say <<-TXT
      You'll want to run something like 
        Observation.find_each{|o|
          o.set_quality_grade
          Observation.where(id: o.id).update_all(quality_grade: o.quality_grade)
          o.elastic_index!
        }
      to reset the quality grade on all obs.
    TXT
  end

  def down
    change_column :observations, :quality_grade, :string, default: 'casual'
    say <<-TXT
      You'll want to run something like 
        Observation.find_each{|o|
          o.set_quality_grade
          Observation.where(id: o.id).update_all(quality_grade: o.quality_grade) 
          o.elastic_index!
        }
      to reset the quality grade on all obs.
    TXT
  end
end

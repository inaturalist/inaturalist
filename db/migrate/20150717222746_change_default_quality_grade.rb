class ChangeDefaultQualityGrade < ActiveRecord::Migration
  def up
    change_column :observations, :quality_grade, :string, default: 'unverifiable', limit: 128
    execute <<-SQL
      UPDATE observations SET quality_grade = 'unverifiable' WHERE quality_grade != 'research'
    SQL
  end

  def down
    change_column :observations, :quality_grade, :string, default: 'casual'
    execute <<-SQL
      UPDATE observations SET quality_grade = 'casual' WHERE quality_grade != 'research'
    SQL
  end
end

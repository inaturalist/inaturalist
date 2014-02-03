class AddCaptiveToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :captive, :boolean
    add_index :observations, :captive
    batch_size = 5000

    if(Observation.count > 0)
      (Observation.maximum(:id) / batch_size).times do |i|
        start = i * batch_size
        stop  = i * batch_size + batch_size - 1
        sql = <<-SQL
          UPDATE observations SET captive = captive_vals.captive FROM (
            SELECT
              observations.id AS observation_id,
              SUM(CASE WHEN agree = 't' THEN 1 ELSE 0 END) < SUM(CASE WHEN agree = 'f' THEN 1 ELSE 0 END) AS captive
            FROM observations
              LEFT OUTER JOIN quality_metrics ON quality_metrics.observation_id = observations.id
            WHERE 
              metric = 'wild'
              AND observations.id BETWEEN #{start} AND #{stop}
            GROUP BY observations.id
          ) AS captive_vals WHERE captive_vals.observation_id = observations.id
        SQL
        execute sql.gsub(/\s+/m, ' ')
      end
    end
    change_column :observations, :captive, :boolean, :default => false
  end

  def down
    remove_column :observations, :captive    
  end
end

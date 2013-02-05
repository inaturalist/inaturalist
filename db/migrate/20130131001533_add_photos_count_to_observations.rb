class AddPhotosCountToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :photos_count, :integer, :default => 0
    add_index :observations, :photos_count
    batch_size = 500
    (Observation.maximum(:id) / batch_size).times do |i|
      start = i * batch_size
      stop  = i * batch_size + batch_size - 1
      sql = <<-SQL
        UPDATE observations
        SET photos_count = op.op_count
        FROM (
          SELECT observation_id, count(*) AS op_count
          FROM observation_photos
          WHERE observation_id BETWEEN #{start} AND #{stop}
          GROUP BY observation_id
        ) AS op
        WHERE 
          op.observation_id = observations.id
          AND id BETWEEN #{start} AND #{stop}
      SQL
      execute sql.gsub(/\s+/m, ' ')
    end
  end

  def down
    remove_column :observations, :photos_count
  end
end

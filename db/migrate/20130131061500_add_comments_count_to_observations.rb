class AddCommentsCountToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :comments_count, :integer, :default => 0
    add_index :observations, :comments_count
    batch_size = 500
    (Observation.maximum(:id) / batch_size).times do |i|
      start = i * batch_size
      stop  = i * batch_size + batch_size - 1
      sql = <<-SQL
        UPDATE observations
        SET comments_count = c.c_count
        FROM (
          SELECT parent_id, count(*) AS c_count
          FROM comments
          WHERE parent_type = 'Observation' AND parent_id BETWEEN #{start} AND #{stop}
          GROUP BY parent_id
        ) AS c
        WHERE 
          c.parent_id = observations.id
          AND id BETWEEN #{start} AND #{stop}
      SQL
      execute sql.gsub(/\s+/m, ' ')
    end
  end

  def down
    remove_column :observations, :comments_count
  end
end

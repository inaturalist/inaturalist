class AddIdentificationsCountToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :identifications_count, :integer, :default => 0
    max_id = Identification.maximum(:id)
    return if max_id.nil?
    batch_size = 1000
    # (1..max_id).in_groups_of(100) do |grp|
    (max_id / batch_size).times do |i|
      start = i * batch_size
      stop  = i * batch_size + batch_size - 1
      execute <<-SQL
        UPDATE observations
        SET identifications_count = ids.count_all
        FROM (
          SELECT observation_id, count(*) AS count_all 
          FROM identifications 
          WHERE id BETWEEN #{start} AND #{stop}
          GROUP BY observation_id
        ) AS ids
        WHERE observations.id = ids.observation_id
      SQL
    end
  end

  def down
    remove_column :observations, :identifications_count
  end
end

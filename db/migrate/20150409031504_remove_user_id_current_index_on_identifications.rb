class RemoveUserIdCurrentIndexOnIdentifications < ActiveRecord::Migration
  def up
    execute <<-SQL
      DROP INDEX index_identifications_on_current
    SQL
  end
  def down
    # ensure nothing will violate the new unique key
    execute <<-SQL
      UPDATE identifications SET current = false
      FROM (
        SELECT observation_id, user_id, max(id) AS max_id
        FROM identifications
        WHERE current = true 
        GROUP BY user_id, observation_id
        HAVING count(*) > 1
      ) as dups
      WHERE 
        identifications.observation_id = dups.observation_id AND 
        identifications.user_id = dups.user_id AND 
        identifications.id != dups.max_id
    SQL
    execute <<-SQL
      CREATE UNIQUE INDEX index_identifications_on_current ON identifications(user_id, observation_id) WHERE current
    SQL
  end
end

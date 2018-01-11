class AddUserObservationIndexToIdentifications < ActiveRecord::Migration
  def up
    sql_query = <<-SQL
      SELECT
        user_id,
        observation_id,
        COUNT(*) count
      FROM 
        identifications
      WHERE
        current = true
      GROUP BY
        user_id,
        observation_id
      HAVING
        COUNT(*) > 1
    SQL
    problem_idents = ActiveRecord::Base.connection.execute( sql_query )
    problem_idents.each do |row|
      puts row["user_id"]
      idents = Identification.where(
        user_id: row["user_id"].to_i,
        observation_id: row["observation_id"].to_i,
        current: true
      )
      idents_count = idents.count
      if idents_count > 1
        ids_to_update = idents.sort_by(&:id)[1..-2].map(&:id)
        Identification.where( id: ids_to_update ).update_all( current: false )
        Identification.elastic_index!( ids: idents.map(&:id) )
        Observation.elastic_index!( ids: [row["observation_id"].to_i] )
      end
    end
    add_index :identifications, [ :user_id, :observation_id ], where: "current", unique: true
  end

  def down
    remove_index :identifications, [ :user_id, :observation_id ]
  end
end

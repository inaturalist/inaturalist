# frozen_string_literal: true

class AddUniqueIndexToVotes < ActiveRecord::Migration[6.1]
  def up
    # Remove existing duplicate ActsAsVotable::Vote, prioritizing the earliest
    observation_ids_to_index = []
    rows = ActiveRecord::Base.connection.execute( "
      SELECT votable_type, votable_id, voter_type, voter_id, vote_scope
      FROM votes
      GROUP BY votable_type, votable_id, voter_type, voter_id, vote_scope
      HAVING count(*) > 1
      ORDER BY count(*) desc" )
    rows.each do | r |
      ActsAsVotable::Vote.where(
        votable_type: r["votable_type"],
        votable_id: r["votable_id"],
        voter_type: r["voter_type"],
        voter_id: r["voter_id"],
        vote_scope: r["vote_scope"]
      ).order( "created_at asc" ).each_with_index do | vote, index |
        next if index.zero?

        if vote.votable_type == "Observation"
          observation_ids_to_index << vote.votable_id
        elsif r["votable_type"] == "Annotation" && vote.votable.resource.is_a?( Observation )
          observation_ids_to_index << vote.votable.resource_id
        end
        vote.destroy
      end
    end
    Observation.elastic_index!(
      ids: observation_ids_to_index,
      delay: true,
      batch_size: 5000,
      run_at: 1.minute.from_now
    )

    add_index :votes, [:votable_type, :votable_id, :voter_type, :voter_id, :vote_scope],
      unique: true, name: "index_votes_on_votable_voter_scope"
    # drop the largely similar but less scoped existing index
    remove_index :votes, name: "index_votes_on_unique_obs_fave"
  end

  def down
    remove_index :votes, name: "index_votes_on_votable_voter_scope"
    # recreate the previously dropped `index_votes_on_unique_obs_fave`
    execute <<-SQL
      CREATE UNIQUE INDEX index_votes_on_unique_obs_fave
      ON votes(
        votable_type,
        votable_id,
        voter_type,
        voter_id
      )
      WHERE
        votable_type = 'Observation' AND voter_type = 'User' AND vote_scope IS NULL AND vote_flag = 't'
    SQL
  end
end

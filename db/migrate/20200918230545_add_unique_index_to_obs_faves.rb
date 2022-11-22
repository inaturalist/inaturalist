class AddUniqueIndexToObsFaves < ActiveRecord::Migration
  def up
    obs_ids = Set.new
    say "Deleting existing duplicate obs fave votes..."
    ActsAsVotable::Vote.
        select( "votable_type, votable_id, voter_type, voter_id, min(id) AS id" ).
        where( "votable_type = 'Observation' AND voter_type = 'User' AND vote_scope IS NULL AND vote_flag = 't'" ).
        group(
          :votable_type,
          :votable_id,
          :voter_type,
          :voter_id
        ).
        having( "count(*) > 1").
        each do |vote|
      ActsAsVotable::Vote.
        where( votable: vote.votable, voter: vote.voter ).
        where( "id != ?", vote.id ).
        delete_all
      obs_ids << vote.votable_id
    end
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
    say "Re-indexing #{obs_ids.size} observations..."
    Observation.elastic_index!( ids: obs_ids.to_a )
  end

  def down
    execute <<-SQL
      DROP INDEX index_votes_on_unique_obs_fave
    SQL
  end
end

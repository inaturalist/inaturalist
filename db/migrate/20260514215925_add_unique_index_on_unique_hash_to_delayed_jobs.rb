# frozen_string_literal: true

class AddUniqueIndexOnUniqueHashToDelayedJobs < ActiveRecord::Migration[6.1]
  def up
    # remove all but the earliest versions of delayed jobs
    # with duplicate non-null unique_hashes
    delayed_jobs_with_duplicate_unique_hashes = Delayed::Job.
      where( "unique_hash IS NOT NULL" ).
      group( :unique_hash ).
      having( "count(*) > 1" ).count
    delayed_jobs_with_duplicate_unique_hashes.each_key do | unique_hash |
      duplicates = Delayed::Job.where( unique_hash: unique_hash ).
        order( id: :asc ).offset( 1 )
      duplicates.each( &:destroy )
    end
    # remove the existing non-unique index so a unique index can be added
    remove_index :delayed_jobs, :unique_hash
    add_index :delayed_jobs, :unique_hash, unique: true
  end

  def down
    remove_index :delayed_jobs, :unique_hash
    # recreating the index without the uniqueness contraint
    add_index :delayed_jobs, :unique_hash
  end
end

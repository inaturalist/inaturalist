# frozen_string_literal: true

module Delayed
  module Backend
    module ActiveRecord
      class Job < ::ActiveRecord::Base
        # there is a migration to add a `unique_hash` column
        # to delayed_jobs. If we set that hash when creating
        # a job then the job will not be created if another
        # exists with the same hash, avoiding duplicate jobs.
        # e.g.
        #   check_list.
        #     delay{ unique_hash: { "CheckList::refresh_listed_taxon": lt.id }).
        #     refresh_listed_taxon(lt.id)
        validates_uniqueness_of :unique_hash, allow_blank: true

        validate :unique_hash_not_known_to_be_taken
        attr_accessor :unique_hash_taken

        # Some Delayed Jobs are attempted to be queued very often,
        # leading to race conditions when the above validates_uniqueness_of
        # validation succeeds but a record with the same unique_hash is added
        # before the job can be saved. Catch these unique_hash uniqueness errors
        # and add an error to the instance instead of raising an exception
        def save( *args, **kwargs, & )
          # create a transaction, or savepoint within an open transaction, so
          # that if a unique index violation occurs at the DB level an open
          # transaction is not left in a fail state, causing subsequent queries
          # to raise errors
          self.class.transaction( requires_new: true ) do
            super
          end
        rescue ::ActiveRecord::RecordNotUnique, ::PG::UniqueViolation => e
          raise unless e.message.include?( "index_delayed_jobs_on_unique_hash" )

          self.unique_hash_taken = true
          errors.add( :unique_hash, :taken )
          false
        end

        def unique_hash_not_known_to_be_taken
          errors.add( :unique_hash, :taken ) if unique_hash_taken
        end
      end
    end
  end
end

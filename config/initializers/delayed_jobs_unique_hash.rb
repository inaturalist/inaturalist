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

      end
    end
  end
end

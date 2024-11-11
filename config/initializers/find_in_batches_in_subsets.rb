# frozen_string_literal: true

module ActiveRecord
  # this wrapper method around `find_in_batches` accepts the same parameters
  # and block, and ultimately calls `find_in_batches` with them. For models that
  # have a single primary key named `id` with ruby type `:integer`, this method
  # will first split the query into smaller chunks based on ID range, and run
  # the `find_in_batches` query against each chunk separately. This can be more
  # performant when the main query involves very large tables with very large
  # indices, or when the main query is otherwise inefficient
  class Relation
    def find_in_batches_in_subsets( **args, &block )
      if klass.primary_key != "id" || klass.columns_hash["id"]&.type != :integer
        raise "Models cannot use `find_in_batches_in_subsets` unless they have an integer `id` primary_key"
      end

      maximum_id = klass.maximum( :id )
      unless maximum_id
        find_in_batches( **args, &block )
        return
      end

      chunk_start_id = 1
      search_chunk_size = 200_000
      while chunk_start_id <= maximum_id
        where( "id >= ?", chunk_start_id ).
          where( "id < ?", chunk_start_id + search_chunk_size ).
          find_in_batches( **args, &block )
        chunk_start_id += search_chunk_size
      end
    end
  end
end

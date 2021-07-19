module ActsAsElasticModel

  extend ActiveSupport::Concern
  @@inserts = 0

  included do
    include Elasticsearch::Model

    attr_accessor :skip_indexing
    attr_accessor :wait_for_index_refresh
    attr_accessor :es_source

    # load the index definition, if it exists
    index_path = File.join(Rails.root, "app/es_indices/#{ name.underscore }_index.rb")
    if File.exists?(index_path)
      ActiveSupport::Dependencies.require_or_load(index_path)
    end

    # set the index name based on the environment, useful for specs
    index_name [ (Rails.env.prod_dev? ? "production" : Rails.env), model_name.collection ].join('_')

    after_commit on: [:create, :update] do
      unless respond_to?(:skip_indexing) && skip_indexing
        elastic_index!
      end
    end

    after_commit on: [:destroy] do
      elastic_delete!
    end

    class << self
      def elastic_search(options = {})
        try_and_try_again( Elasticsearch::Transport::Transport::Errors::ServiceUnavailable, sleep: 1, tries: 10 ) do
          begin
            __elasticsearch__.search(ElasticModel.search_hash(options))
          rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
            Logstasher.write_exception(e)
            Rails.logger.error "[Error] elastic_search failed: #{ e }"
            Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
          end
        end
      end

      def elastic_paginate(options={})
        options = options.dup
        options[:page] ||= 1
        options[:per_page] ||= 20
        options[:source] ||= options[:keep_es_source] ? "*" : [ "id" ]
        result = elastic_search(options).
          per_page(options[:per_page]).page(options[:page])
        result_to_will_paginate_collection(result, options)
      end

      # standard way to bulk index instances. Called without options it will
      # page through all instances 1000 at a time (default for find_in_batches)
      # You can also send options, including scope:
      #   Place.elastic_index!(batch_size: 20)
      #   Place.elastic_index!(scope: Place.where(id: [1,2,3,...]), batch_size: 20)
      def elastic_index!(options = { })
        options[:batch_size] ||=
          defined?(self::DEFAULT_ES_BATCH_SIZE) ? self::DEFAULT_ES_BATCH_SIZE : 1000
        options[:sleep] ||=
          defined?(self::DEFAULT_ES_BATCH_SLEEP) ? self::DEFAULT_ES_BATCH_SLEEP : 1
        debug = options.delete(:debug)
        filter_scope = options.delete(:scope)
        # this method will accept an existing scope
        scope = (filter_scope && filter_scope.is_a?(ActiveRecord::Relation)) ?
          filter_scope : self.all
        # it also accepts an array of IDs to filter by
        if filter_ids = options.delete(:ids)
          filter_ids.compact!
          batch_sleep = options.delete(:sleep)
          if filter_ids.length > options[:batch_size]
            # call again for each batch, then return
            filter_ids.each_slice(options[:batch_size]) do |slice|
              elastic_index!(options.merge(ids: slice))
              if batch_sleep && !options[:delay]
                # sleep after index an ID batch, since during indexing
                # we only sleep when indexing multiple batches, and here
                # we explicitly requested a single batch to be indexed
                sleep batch_sleep.to_i
              end
            end
            return
          end
          scope = scope.where(id: filter_ids)
        end
        if indexed_before = options.delete(:indexed_before)
          if column_names.include?( "last_indexed_at" )
            scope = scope.where("last_indexed_at IS NULL OR last_indexed_at < ?", indexed_before)
          end
        end
        # indexing can be delayed
        if options.delete(:delay)
          # make sure to fetch the results of the scope and store
          # the resulting IDs instead of scopes for DelayedJobs.
          # For example, delayed calls this like are very efficient:
          #   Observation.elastic_index!(scope: User.find(1).observations, delay: true)
          result_ids = scope.order(:id).pluck(:id)
          return unless result_ids.any?
          id_hash = Digest::MD5.hexdigest( result_ids.join( "," ) )
          queue = if result_ids.size > 50
            "throttled"
          end
          return self.delay(
            unique_hash: { "#{self.name}::delayed_index": id_hash },
            queue: queue
          ).elastic_index!( options.merge(
            ids: result_ids,
            indexed_before: 5.minutes.from_now.strftime("%FT%T"),
            wait_for_index_refresh: true
          ) )
        end
        # now we can preload all associations needed for efficient indexing
        if self.respond_to?(:load_for_index)
          scope = scope.load_for_index
        end
        wait_for_index_refresh = options.delete(:wait_for_index_refresh)
        batch_sleep = options.delete(:sleep)
        batches_indexed = 0
        scope.find_in_batches(options) do |batch|
          if batch_sleep && batches_indexed > 0
            # sleep only if more than one batch is being indexed
            sleep batch_sleep.to_i
          end
          if debug && batch && batch.length > 0
            Rails.logger.info "[INFO #{Time.now}] Starting to index #{self.name} :: #{batch[0].id}"
          end
          bulk_index(batch, wait_for_index_refresh: wait_for_index_refresh)
          batches_indexed += 1
        end
        __elasticsearch__.refresh_index! if Rails.env.test?
      end

      def elastic_sync(start_id, end_id, options)
        return if !start_id || !end_id || start_id >= end_id
        options[:batch_size] ||=
          defined?(self::DEFAULT_ES_BATCH_SIZE) ? self::DEFAULT_ES_BATCH_SIZE : 1000
        batch_start_id = start_id
        while batch_start_id <= end_id
          Rails.logger.debug "[DEBUG] Processing from #{ batch_start_id }"
          batch_end_id = batch_start_id + options[:batch_size]
          if batch_end_id > end_id + 1
            batch_end_id = end_id + 1
          end
          scope = self.where("id >= ? AND id < ?", batch_start_id, batch_end_id)
          if self.respond_to?(:load_for_index)
            scope = scope.load_for_index
          end
          batch = scope.to_a
          prepare_for_index(batch)
          results = elastic_search(
            sort: { id: :asc },
            size: options[:batch_size],
            filters: [
              { range: { id: { gte: batch_start_id } } },
              { range: { id: { lt: batch_end_id } } }
            ],
            source: ["id"]
          ).group_by{ |r| r.id.to_i }
          bulk_index(batch, skip_prepare_batch: true)
          ids_only_in_es = results.keys - batch.map(&:id)
          unless ids_only_in_es.empty?
            Rails.logger.debug "[DEBUG] Deleting vestigial docs in ES: #{ ids_only_in_es }"
            elastic_delete_by_ids!( [ids_only_in_es] )
          end
          batch_start_id = batch_end_id
        end
      end

      def elastic_prune(start_id, end_id, options)
        return if !start_id || !end_id || start_id >= end_id
        options[:batch_size] ||=
          defined?(self::DEFAULT_ES_BATCH_SIZE) ? self::DEFAULT_ES_BATCH_SIZE : 1000
        batch_start_id = start_id
        while batch_start_id <= end_id
          Rails.logger.debug "[DEBUG] Processing from #{ batch_start_id }"
          batch_end_id = batch_start_id + options[:batch_size]
          if batch_end_id > end_id + 1
            batch_end_id = end_id + 1
          end
          scope = self.where("id >= ? AND id < ?", batch_start_id, batch_end_id)
          batch_ids = scope.pluck(:id)
          ids_only_in_es = elastic_search(
            sort: { id: :asc },
            size: options[:batch_size],
            filters: [
              { range: { id: { gte: batch_start_id } } },
              { range: { id: { lt: batch_end_id } } },
              { bool: {
                must_not: {
                  terms: { id: batch_ids }
                }
              } }
            ],
            source: ["id"]
          ).map(&:id)
          unless ids_only_in_es.empty?
            Rails.logger.debug "[DEBUG] Deleting vestigial docs in ES: #{ ids_only_in_es }"
            elastic_delete_by_ids!( [ids_only_in_es] )
          end
          batch_start_id = batch_end_id
        end
      end

      def result_to_will_paginate_collection(result, options={})
        try_and_try_again( PG::ConnectionBad, sleep: 20 ) do
          begin
            records = options[:keep_es_source] ?
              result.records.map_with_hit do |record, hit|
                record.es_source = hit._source
                record
              end : result.records.to_a
            elastic_ids = result.results.results.map{ |r| r.id.to_i }
            elastic_ids_to_delete = elastic_ids - records.map(&:id)
            elastic_delete_by_ids!( elastic_ids_to_delete )
            WillPaginate::Collection.create(result.current_page, result.per_page,
              result.total_entries - elastic_ids_to_delete.count) do |pager|
              pager.replace(records)
            end
          rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
            Logstasher.write_exception(e)
            Rails.logger.error "[Error] Elasticsearch query failed: #{ e }"
            Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
            WillPaginate::Collection.new(1, 30, 0)
          end
        end
      end

      def refresh_es_index
        __elasticsearch__.refresh_index! unless Rails.env.test?
      end

      def preload_for_elastic_index( instances )
        return if instances.blank?
        klass = instances.first.class
        if klass.respond_to?(:load_for_index)
          klass.preload_associations( instances,
            klass.load_for_index.values[:includes] )
        end
      end

      def elastic_delete_by_ids!( ids, options = { } )
        return if ids.blank?
        bulk_delete( ids, options )
        __elasticsearch__.refresh_index! if Rails.env.test?
      end

      private

      # standard wrapper for bulk indexing with Elasticsearch::Model
      def bulk_index(batch, options = { })
        begin
          __elasticsearch__.client.bulk({
            index: __elasticsearch__.index_name,
            type: __elasticsearch__.document_type,
            body: prepare_for_index(batch, options),
            refresh: options[:wait_for_index_refresh] ? "wait_for" : false
          })
          if batch && batch.length > 0 && batch.first.respond_to?(:last_indexed_at)
            where(id: batch).update_all(last_indexed_at: Time.now)
          end
          GC.start
        rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception(e)
          Rails.logger.error "[Error] elastic_index! failed: #{ e }"
          Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
        end
      end

      # map each instance into its indexable form with `as_indexed_json`
      def prepare_for_index(batch, options = { })
        # some models need some extra preparation for faster indexing.
        # I tried to just define a custom `prepare_for_index` in
        # Taxon, but this one from this module took precedence
        if self.respond_to?(:prepare_batch_for_index) && !options[:skip_prepare_batch]
          prepare_batch_for_index(batch)
        end
        batch.map do |obj|
          { index: { _id: obj.id, data: obj.as_indexed_json } }
        end
      end

      def bulk_delete( ids, options = { } )
        begin
          __elasticsearch__.client.bulk({
            index: __elasticsearch__.index_name,
            type: __elasticsearch__.document_type,
            body:  ids.map do |id|
              { delete: { _id: id } }
            end,
            refresh: options[:wait_for_index_refresh] ? "wait_for" : false
          })
        rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception(e)
          Rails.logger.error "[Error] elastic_delete! failed: #{ e }"
          Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
        end
      end

    end

    def elastic_index!
      original_associations_loaded = self.association_cache.keys
      begin
        index_options = { }
        if respond_to?(:wait_for_index_refresh) && wait_for_index_refresh
          index_options[:refresh] = "wait_for"
        end
        __elasticsearch__.index_document( index_options )
        # in the test ENV, we will need to wait for changes to be applied
        self.class.__elasticsearch__.refresh_index! if Rails.env.test?
        if respond_to?(:last_indexed_at) && !destroyed?
          update_column(:last_indexed_at, Time.now)
        end
        # indexing can preload a lot of associations which can hang around and cause
        # memory usage to spike. To avoid that, reset (i.e. unload the association)
        # any associations that were loaded purely for indexing
        associations_added_for_indexing = self.association_cache.keys - original_associations_loaded
        associations_added_for_indexing.each do |k|
          if self.send( k ).is_a?( ActiveRecord::Associations::CollectionProxy )
            self.send( k ).reset
          end
        end
        @@inserts += 1
        # garbage collect after a small batch of individual instance indexing
        # don't do this for every elastic_index! as GC is somewhat expensive
        GC.start if @@inserts % 10 == 0
      rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
        Logstasher.write_exception(e)
        Rails.logger.error "[Error] elastic_index! failed: #{ e }"
        Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
      end
    end

    def elastic_delete!
      try_and_try_again( Elasticsearch::Transport::Transport::Errors::Conflict, sleep: 1, tries: 10 ) do
        begin
          __elasticsearch__.delete_document
          # in the test ENV, we will need to wait for changes to be applied
          self.class.__elasticsearch__.refresh_index! if Rails.env.test?
        rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
          Logstasher.write_exception(e)
          Rails.logger.error "[Error] elastic_delete! failed: #{ e }"
          Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
        end
      end
    end

    private

    # usually called within as_indexed_json to make sure the instance
    # has all associations it needs. It is fast to check even if the
    # associations have been loaded. This should help minimize the number
    # of sql calls needed for non-bulk indexing
    def preload_for_elastic_index
      if self.class.respond_to?(:load_for_index)
        self.class.preload_associations(self,
          self.class.load_for_index.values[:includes])
      end
    end

  end
end

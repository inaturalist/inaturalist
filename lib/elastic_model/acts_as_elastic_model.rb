# frozen_string_literal: true

module ActsAsElasticModel
  def self.included( base )
    base.extend ClassMethods
  end

  module ClassMethods
    def acts_as_elastic_model( options = {} )
      options[:lifecycle_callbacks] ||= [:create, :update, :destroy]
      @inserts = 0
      include Elasticsearch::Model

      attr_accessor :skip_indexing
      attr_accessor :wait_for_index_refresh
      attr_accessor :es_source

      # load the index definition, if it exists
      index_path = File.join( Rails.root, "app/es_indices/#{name.underscore}_index.rb" )
      if File.exist?( index_path )
        ActiveSupport::Dependencies.require_or_load( index_path )
      end

      # set the index name based on the environment, useful for specs
      index_prefix = ENV.fetch( "INAT_ES_INDEX_PREFIX" ) { ( Rails.env.prod_dev? ? "production" : Rails.env ) }
      index_name [index_prefix, model_name.collection].join( "_" )

      if options[:lifecycle_callbacks]&.include?( :create )
        after_commit on: :create do
          unless self&.skip_indexing
            elastic_index!
          end
        end
      end
      if options[:lifecycle_callbacks]&.include?( :update )
        after_commit on: :update do
          unless self&.skip_indexing
            elastic_index!
          end
        end
      end
      if options[:lifecycle_callbacks]&.include?( :destroy )
        after_commit on: :destroy do
          unless self&.skip_indexing
            elastic_delete!
          end
        end
      end

      include ActsAsElasticModel::InstanceMethods
      extend ActsAsElasticModel::SingletonMethods
    end
  end

  module SingletonMethods
    def elastic_search(options = {})
      try_and_try_again( [
        Elastic::Transport::Transport::Errors::ServiceUnavailable,
        Elastic::Transport::Transport::Errors::TooManyRequests], sleep: 1, tries: 10 ) do
        begin
          __elasticsearch__.search(ElasticModel.search_hash(options))
        rescue Elastic::Transport::Transport::Errors::BadRequest => e
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

    def elastic_get( id, options = { } )
      begin
        __elasticsearch__.client.get( index: index_name, id: id )
      rescue Elastic::Transport::Transport::Errors::NotFound => a
        nil
      end
    end

    def elastic_mget( ids, options = {} )
      return [] if ids.empty?

      __elasticsearch__.client.mget(
        index: index_name,
        body: {
          docs: ids.map do | id |
            { _id: id }
          end
        },
        _source: options[:source]
      )["docs"].map {| d | d["_source"] }.compact
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
      run_at = options.delete(:run_at)
      # this method will accept an existing scope
      scope = (filter_scope && filter_scope.is_a?(ActiveRecord::Relation)) ?
        filter_scope : self.all
      # it also accepts an array of IDs to filter by
      if filter_ids = options.delete(:ids)
        filter_ids = filter_ids.compact.uniq
        batch_sleep = options.delete(:sleep)
        if filter_ids.length > options[:batch_size]
          # call again for each batch, then return
          filter_ids.each_slice(options[:batch_size]) do |slice|
            elastic_index!(options.merge(ids: slice, run_at: run_at))
            if batch_sleep.is_a?( Numeric ) && !options[:delay]
              # sleep after index an ID batch, since during indexing
              # we only sleep when indexing multiple batches, and here
              # we explicitly requested a single batch to be indexed
              sleep batch_sleep
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
          queue: queue,
          run_at: run_at
        ).elastic_index!( options.except( :batch_size ).merge(
          ids: result_ids,
          indexed_before: 5.minutes.from_now.strftime("%FT%T")
        ) )
      end
      # now we can preload all associations needed for efficient indexing
      if self.respond_to?(:load_for_index)
        scope = scope.load_for_index
      end
      wait_for_index_refresh = options.delete(:wait_for_index_refresh)
      batch_sleep = options.delete(:sleep)
      batches_indexed = 0
      scope.find_in_batches(**options) do |batch|
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

    def elastic_sync( opts = {} )
      options = opts.clone
      options[:index_records] = true unless options.include?( :index_records )
      options[:only_index_missing] = false unless options.include?( :index_records )
      options[:remove_orphans] = true unless options.include?( :remove_orphans )
      if !options[:index_records] == false && !options[:remove_orphans]
        return
      end

      batch_start_id = options[:start_id] || 1
      maximum_id = options[:end_id] || maximum( :id )
      batch_size = options[:batch_size] || 1_000
      start_time = Time.now
      while batch_start_id <= maximum_id
        run_time = ( Time.now - start_time ).round( 2 )
        Rails.logger.debug "Loop starting at #{batch_start_id}; time: #{run_time}"
        batch_id_below = batch_start_id + batch_size
        ids_from_db = where( "id >= ?", batch_start_id ).
          where( "id < ?", batch_id_below ).pluck( :id )
        ids_from_es = elastic_search(
          sort: { id: :asc },
          size: batch_size,
          filters: [
            { range: { id: { gte: batch_start_id } } },
            { range: { id: { lt: batch_id_below } } }
          ],
          source: ["id"]
        ).map {| doc | doc.id.to_i }
        if options[:index_records]
          ids_to_index = if options[:only_index_missing]
            ids_from_db - ids_from_es
          else
            ids_from_db
          end

          unless ids_to_index.empty?
            Rails.logger.debug "[DEBUG] Indexing #{ids_to_index.size} records"
            elastic_index!( ids: ids_to_index, sleep: 0.01 )
          end
        end

        if options[:remove_orphans]
          ids_only_in_es = ids_from_es - ids_from_db
          unless ids_only_in_es.empty?
            Rails.logger.debug "[DEBUG] Deleting vestigial docs in ES: #{ids_only_in_es}"
            elastic_delete_by_ids!( ids_only_in_es )
          end
        end
        batch_start_id += batch_size
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
        rescue Elastic::Transport::Transport::Errors::BadRequest => e
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
      return unless klass.respond_to?( :load_for_index )

      klass.preload_associations( instances,
        klass.load_for_index.values[:includes] )
    end

    def elastic_delete_by_ids!( ids, options = {} )
      return if ids.blank?

      bulk_delete( ids, options )
      __elasticsearch__.refresh_index! if Rails.env.test?
    end

    private

    # standard wrapper for bulk indexing with Elasticsearch::Model
    def bulk_index( batch, options = {} )
      batch_to_index = if respond_to?( :prune_batch_for_index )
        prune_batch_for_index( batch )
      else
        batch
      end
      return if batch_to_index.empty?

      try_and_try_again(
        [
          Elastic::Transport::Transport::Errors::ServiceUnavailable,
          Elastic::Transport::Transport::Errors::TooManyRequests
        ], sleep: 1, tries: 10
      ) do
        begin
          __elasticsearch__.client.bulk( {
            index: __elasticsearch__.index_name,
            body: prepare_for_index( batch_to_index, options ),
            refresh: options[:wait_for_index_refresh] ? "wait_for" : false
          } )
          if batch_to_index.first.respond_to?( :last_indexed_at )
            ActiveRecord::Base.connection.without_sticking do
              where( id: batch_to_index ).update_all( last_indexed_at: Time.now )
            end
          end
          GC.start
        rescue Elastic::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception( e )
          Rails.logger.error "[Error] elastic_index! failed: #{e}"
          Rails.logger.error "Backtrace:\n#{e.backtrace[0..30].join( "\n" )}\n..."
        end
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
      try_and_try_again( [
        Elastic::Transport::Transport::Errors::ServiceUnavailable,
        Elastic::Transport::Transport::Errors::TooManyRequests], sleep: 1, tries: 10 ) do
        begin
          __elasticsearch__.client.bulk({
            index: __elasticsearch__.index_name,
            body: ids.map do |id|
              { delete: { _id: id } }
            end,
            refresh: options[:wait_for_index_refresh] ? "wait_for" : false
          })
        rescue Elastic::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception(e)
          Rails.logger.error "[Error] elastic_delete! failed: #{ e }"
          Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
        end
      end
    end
  end

  module InstanceMethods
    def elastic_index!
      if self.class.respond_to?( :prune_batch_for_index ) && self.class.prune_batch_for_index( [self] ).empty?
        return
      end

      try_and_try_again( [
        Elastic::Transport::Transport::Errors::ServiceUnavailable,
        Elastic::Transport::Transport::Errors::TooManyRequests], sleep: 1, tries: 10 ) do
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

          inserts = self.class.instance_variable_get( "@inserts" ) + 1
          self.class.instance_variable_set( "@inserts", inserts )
          # garbage collect after a small batch of individual instance indexing
          # don't do this for every elastic_index! as GC is somewhat expensive
          GC.start if ( inserts % 100 ).zero?
        rescue Elastic::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception(e)
          Rails.logger.error "[Error] elastic_index! failed: #{ e }"
          Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
        end
      end
    end

    def elastic_delete!
      try_and_try_again( [
        Elastic::Transport::Transport::Errors::ServiceUnavailable,
        Elastic::Transport::Transport::Errors::TooManyRequests,
        Elastic::Transport::Transport::Errors::Conflict], sleep: 1, tries: 10 ) do
        begin
          __elasticsearch__.delete_document
          # in the test ENV, we will need to wait for changes to be applied
          self.class.__elasticsearch__.refresh_index! if Rails.env.test?
        rescue Elastic::Transport::Transport::Errors::NotFound => e
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

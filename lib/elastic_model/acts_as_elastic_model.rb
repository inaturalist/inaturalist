module ActsAsElasticModel

  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model

    attr_accessor :skip_indexing

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
        begin
          __elasticsearch__.search(ElasticModel.search_hash(options), preference: "_primary_first")
        rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception(e)
          Rails.logger.error "[Error] elastic_search failed: #{ e }"
          Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
        end
      end

      def elastic_paginate(options={})
        options[:page] ||= 1
        # 20 was the default of Sphinx, which Elasticsearch is replacing for us
        options[:per_page] ||= 20
        options[:fields] ||= :id
        result = elastic_search(options).
          per_page(options[:per_page]).page(options[:page])
        result_to_will_paginate_collection(result)
      end

      # standard way to bulk index instances. Called without options it will
      # page through all instances 1000 at a time (default for find_in_batches)
      # You can also send options, including scope:
      #   Place.elastic_index!(batch_size: 20)
      #   Place.elastic_index!(scope: Place.where(id: [1,2,3,...]), batch_size: 20)
      def elastic_index!(options = { })
        filter_scope = options.delete(:scope)
        # this method will accept an existing scope
        scope = (filter_scope && filter_scope.is_a?(ActiveRecord::Relation)) ?
          filter_scope : self.all
        # it also accepts an array of IDs to filter by
        if filter_ids = options.delete(:ids)
          if filter_ids.length > 1000
            # call again for each batch, then return
            filter_ids.each_slice(1000) do |slice|
              elastic_index!(options.merge(ids: slice))
            end
            return
          end
          scope = scope.where(id: filter_ids)
        end
        # indexing can be delayed
        if options.delete(:delay)
          # make sure to fetch the results of the scope and store
          # the resulting IDs instead of scopes for DelayedJobs.
          # For example, delayed calls this like are very efficient:
          #   Observation.elastic_index!(scope: User.find(1).observations, delay: true)
          result_ids = scope.select(:id).order(:id).map(&:id)
          return unless result_ids.any?
          return self.delay.elastic_index!(options.merge(ids: result_ids))
        end
        # now we can preload all associations needed for efficient indexing
        if self.respond_to?(:load_for_index)
          scope = scope.load_for_index
        end
        scope.find_in_batches(options) do |batch|
          bulk_index(batch)
        end
        __elasticsearch__.refresh_index! if Rails.env.test?
      end

      def elastic_delete!(options = {})
        begin
          __elasticsearch__.client.delete_by_query(index: index_name,
            body: ElasticModel.search_hash(options))
          __elasticsearch__.refresh_index! if Rails.env.test?
        rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception(e)
          Rails.logger.error "[Error] elastic_search failed: #{ e }"
          Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
        end
      end

      def elastic_sync(options = {})
        batch_size = options[:batch_size] || 1000
        load_for_index.find_in_batches(batch_size: batch_size) do |batch|
          prepare_for_index(batch)
          Rails.logger.debug "[DEBUG] Processing from #{ batch.first.id }"
          results = elastic_search(
            sort: { id: :asc },
            size: batch_size,
            filters: [
              { range: { id: { gte: batch.first.id } } },
              { range: { id: { lte: batch.last.id } } }
            ]
          ).group_by{ |r| r.id.to_i }
          batch.each do |obj|
            if result = results[ obj.id ]
              result = result.first._source
              if obj.as_indexed_json.to_json == result.to_json
                # it's OK
              else
                Rails.logger.debug "[DEBUG] Object #{ obj } is out of sync"
                obj.elastic_index!
              end
            else
              Rails.logger.debug "[DEBUG] Object #{ obj } is not in ES"
              obj.elastic_index!
            end
          end
          ids_only_in_es = results.keys - batch.map(&:id)
          unless ids_only_in_es.empty?
            Rails.logger.debug "[DEBUG] Deleting vestigial docs in ES: #{ ids_only_in_es }"
            elastic_delete!(where: { id: ids_only_in_es } )
          end
        end
      end

      def result_to_will_paginate_collection(result)
        begin
          records = result.records.to_a
          elastic_ids = result.results.results.map{ |r| r.id.to_i }
          elastic_ids_to_delete = elastic_ids - records.map(&:id)
          unless elastic_ids_to_delete.blank?
            elastic_delete!(where: { id: elastic_ids_to_delete })
          end
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

      private

      # standard wrapper for bulk indexing with Elasticsearch::Model
      def bulk_index(batch)
        begin
          __elasticsearch__.client.bulk({
            index: __elasticsearch__.index_name,
            type: __elasticsearch__.document_type,
            body: prepare_for_index(batch)
          })
          if batch && batch.length > 0 && batch.first.respond_to?(:last_indexed_at)
            where(id: batch).update_all(last_indexed_at: Time.now)
          end
        rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
          Logstasher.write_exception(e)
          Rails.logger.error "[Error] elastic_index! failed: #{ e }"
          Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
        end
      end

      # map each instance into its indexable form with `as_indexed_json`
      def prepare_for_index(batch)
        # some models need some extra preparation for faster indexing.
        # I tried to just define a custom `prepare_for_index` in
        # Taxon, but this one from this module took precedence
        if self.respond_to?(:prepare_batch_for_index)
          prepare_batch_for_index(batch)
        end
        batch.map do |obj|
          { index: { _id: obj.id, data: obj.as_indexed_json } }
        end
      end
    end

    def elastic_index!
      begin
        __elasticsearch__.index_document
        # in the test ENV, we will need to wait for changes to be applied
        self.class.__elasticsearch__.refresh_index! if Rails.env.test?
        if respond_to?(:last_indexed_at) && !destroyed?
          update_column(:last_indexed_at, Time.now)
        end
      rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
        Logstasher.write_exception(e)
        Rails.logger.error "[Error] elastic_index! failed: #{ e }"
        Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
      end
    end

    def elastic_delete!
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

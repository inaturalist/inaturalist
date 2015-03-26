module ActiveRecord
  class Base

    class << self

      def elastic_model(options={})
        include Elasticsearch::Model

        index_name [ Rails.env, model_name.collection.gsub(/\//, '-') ].join('_')

        after_commit on: [:create, :update] do
          __elasticsearch__.index_document
        end

        after_commit on: [:destroy] do
          __elasticsearch__.delete_document
        end
      end

      def elastic_search_for_ids(keyword)
        __elasticsearch__.search(keyword)
      end

      def elastic_search(options = {})
        search_criteria = ElasticModel.search_criteria(options)
        search_filter = ElasticModel.envelope_filter(options)
        search_filter ||= ElasticModel.place_filter(options)
        if !search_filter && options[:filter]
          search_filter = options[:filter]
        end
        query = search_criteria.empty? ?
          { match_all: { } } :
          { bool: { must: search_criteria } }
        if search_filter
          query = {
            filtered: {
              query: query,
              filter: search_filter } }
        end
        elastic_hash = { query: query }
        if options[:sort]
          elastic_hash[:sort] = options[:sort]
        end
        if options[:fields]
          elastic_hash[:fields] = options[:fields]
        end
        if options[:aggregate]
          elastic_hash[:aggs] = Hash[options[:aggregate].map{ |k, v|
            [ k, { terms: { field: v.first[0], size: v.first[1] } } ]
          }]
        end
        __elasticsearch__.search(elastic_hash)
      end

      def elastic_paginate(options)
        options[:page] ||= 1
        options[:per_page] ||= 30
        options[:fields] = :id
        result = elastic_search(options).
          per_page(options[:per_page]).page(options[:page])
        ElasticModel.result_to_will_paginate_collection(result)
      end
    end

    def preload_for_elastic_index
      if self.class.respond_to?(:preload_for_elastic_index)
        self.class.preload_associations(self,
          self.class.preload_for_elastic_index.values[:includes])
      end
    end

  end
end

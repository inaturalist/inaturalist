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

      def elastic_search(options = {})
        __elasticsearch__.search(ElasticModel.search_hash(options))
      end

      def elastic_paginate(options={})
        options[:page] ||= 1
        # 20 was the default of Sphinx, which Elasticsearch is replacing for us
        options[:per_page] ||= 20
        options[:fields] ||= :id
        result = elastic_search(options).
          per_page(options[:per_page]).page(options[:page])
        ElasticModel.result_to_will_paginate_collection(result)
      end
    end

    def self.elastic_index!(options={})
      if self.respond_to?(:load_for_index)
        options[:scope] ||= :load_for_index
      end
      __elasticsearch__.import(options)
    end

    def preload_for_elastic_index
      if self.class.respond_to?(:load_for_index)
        self.class.preload_associations(self,
          self.class.load_for_index.values[:includes])
      end
    end

  end
end

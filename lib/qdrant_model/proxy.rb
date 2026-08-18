# frozen_string_literal: true

module ActsAsQdrantModel
  class << self
    attr_accessor :client
  end

  class ClassMethodsProxy
    MAX_BATCH_SIZE = 64

    attr_reader :target, :client, :collection_name, :configuration, :lifecycle_callbacks

    def initialize( target, options = {} )
      @target = target
      @client = ActsAsQdrantModel.client
      collection_prefix = ENV.fetch( "INAT_QDRANT_COLLECTION_PREFIX" ) do
        Rails.env.prod_dev? ? "production" : Rails.env
      end
      @collection_name = [collection_prefix, target.model_name.collection].join( "_" )
      @lifecycle_callbacks = options[:lifecycle_callbacks] ||= [:create, :update, :destroy]
    end

    def inspect
      "[PROXY] #{target.inspect}"
    end

    def set_configuration( configuration )
      @configuration = configuration
    end

    def enabled?
      !!client
    end

    def collection_exists?
      return false unless enabled?

      begin
        client.collections.get( collection_name: collection_name )
      rescue Faraday::ResourceNotFound
        return false
      end
      true
    end

    def create_collection!( options = {} )
      return unless enabled?

      delete_collection! if options[:force]

      return if collection_exists?

      client.collections.create(
        **configuration[:collection_parameters],
        collection_name: collection_name
      )

      create_indices!
    end

    def create_indices!
      return unless enabled?

      payload_indices = @configuration[:payload_indices] || {}
      payload_indices.each do | field_name, field_schema |
        # Create index for field in collection
        client.collections.create_index(
          collection_name: collection_name,
          field_name: field_name,
          field_schema: field_schema,
          wait: true
        )
      end
    end

    def delete_collection!
      return unless enabled?

      client.collections.delete( collection_name: collection_name )
    end

    def upsert_points( points )
      return unless enabled?
      return if points.blank?

      points.in_groups_of( MAX_BATCH_SIZE, false ) do | batch |
        client.points.upsert(
          collection_name: collection_name,
          points: batch,
          wait: true
        )
      end
    end

    def count( filter = {} )
      return 0 unless enabled?

      response = client.points.count(
        collection_name: collection_name,
        filter: filter,
        exact: true
      )
      response["result"]["count"]
    end

    def get( id )
      return unless enabled?

      begin
        response = client.points.get(
          collection_name: collection_name,
          id: id
        )
        response["result"]
      rescue Faraday::ResourceNotFound
        nil
      end
    end

    def get_all( ids )
      return [] unless enabled?

      response = client.points.get_all(
        collection_name: collection_name,
        ids: ids,
        with_payload: true
      )
      response["result"]
    end

    def delete( ids )
      return unless enabled?

      client.points.delete(
        collection_name: collection_name,
        points: ids,
        wait: true
      )
    end
  end

  class InstanceMethodsProxy
    attr_reader :target, :class_proxy

    def initialize( target )
      @target = target
      @class_proxy = target.class.__qdrant__
    end

    def enabled?
      class_proxy.enabled?
    end

    def upsert_point
      return unless enabled?

      qdrant_json = target.as_qdrant_json
      return if qdrant_json.blank?

      class_proxy.upsert_points( [qdrant_json] )
    end

    def delete_point
      return unless enabled?

      class_proxy.delete( [@target.id] )
    end
  end
end

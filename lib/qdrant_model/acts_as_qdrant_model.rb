# frozen_string_literal: true

module ActsAsQdrantModel
  class Error < StandardError; end

  class << self
    attr_accessor :client
  end

  def self.included( base )
    base.extend ClassMethods
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

    def collection_exists?
      begin
        client.collections.get( collection_name: collection_name )
      rescue Faraday::ResourceNotFound
        return false
      end
      true
    end

    def create_collection!( options = {} )
      delete_collection! if options[:force]

      return if collection_exists?

      client.collections.create(
        **configuration[:collection_parameters],
        collection_name: collection_name
      )

      create_indices!
    end

    def create_indices!
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
      client.collections.delete( collection_name: collection_name )
    end

    def upsert_points( points )
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
      response = client.points.count(
        collection_name: collection_name,
        filter: filter,
        exact: true
      )
      response["result"]["count"]
    end

    def get( id )
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
      response = client.points.get_all(
        collection_name: collection_name,
        ids: ids,
        with_payload: true
      )
      response["result"]
    end

    def delete( ids )
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

    def upsert_point
      qdrant_json = target.as_qdrant_json
      return if qdrant_json.blank?

      class_proxy.upsert_points( [qdrant_json] )
    end

    def delete_point
      class_proxy.delete( [@target.id] )
    end
  end

  module ClassMethods
    def acts_as_qdrant( options = {} )
      if instance_methods.include?( :qdrant_index! )
        raise Error, "acts_as_qdrant already initialized for #{name}"
      end

      collection_path = File.join(
        Rails.root,
        "app/qdrant_collections/#{name.underscore}_collection.rb"
      )
      unless File.exist?( collection_path )
        raise Error, "acts_as_qdrant collection definition does not exist for #{name}"
      end

      attr_accessor :skip_qdrant_indexing

      include ActsAsQdrantModel::InstanceMethods
      extend ActsAsQdrantModel::SingletonMethods

      @__qdrant__ ||= ClassMethodsProxy.new( self, options )
      ActiveSupport::Dependencies.require_or_load( collection_path )

      after_commit on: :create do
        unless skip_qdrant_indexing || !self.class.qdrant_lifecycle_callback_enabled( :create )
          qdrant_index!
        end
      end
      after_commit on: :update do
        unless skip_qdrant_indexing || !self.class.qdrant_lifecycle_callback_enabled( :update )
          qdrant_index!
        end
      end
      after_commit on: :destroy do
        unless skip_qdrant_indexing || !self.class.qdrant_lifecycle_callback_enabled( :destroy )
          qdrant_delete!
        end
      end
      self
    end
  end

  module SingletonMethods
    def __qdrant__
      @__qdrant__
    end

    def qdrant_collection_settings( configuration )
      __qdrant__.set_configuration( configuration )
    end

    def qdrant_lifecycle_callback_enabled( action )
      __qdrant__.lifecycle_callbacks.include?( action )
    end

    def qdrant_count( filter = {} )
      __qdrant__.count( filter )
    end

    def qdrant_get( id )
      __qdrant__.get( id )
    end

    def qdrant_get_all( ids )
      __qdrant__.get_all( ids )
    end

    def qdrant_delete_by_ids!( ids )
      __qdrant__.delete( ids )
    end

    # standard way to bulk index instances. Called without options it will
    # page through all instances 200 at a time (default for find_in_batches)
    # You can also send options, including scope:
    #   TaxonPhoto.qdrant_index!( batch_size: 20 )
    #   TaxonPhoto.qdrant_index!( scope: Place.where( id: [1,2,3,...] ), batch_size: 20 )
    def qdrant_index!( options = {} )
      if options[:scope] && options[:ids]
        raise Error, "Cannot pass both :scope and :ids to qdrant_index!"
      end

      options[:batch_size] ||= 200
      debug = options.delete( :debug )
      filter_scope = options.delete( :scope )
      # this method will accept an existing scope
      scope = filter_scope.is_a?( ActiveRecord::Relation ) ? filter_scope : all
      # it also accepts an array of IDs to filter by
      filter_ids = options.delete( :ids )
      if filter_ids
        filter_ids = filter_ids.compact.uniq
        if filter_ids.length > options[:batch_size]
          # call again for each batch, then return
          filter_ids.each_slice( options[:batch_size] ) do | slice |
            qdrant_index!( options.merge( ids: slice ) )
          end
          return
        end
        scope = scope.where( id: filter_ids )
      end

      if options.delete( :delay )
        delayed_qdrant_index( scope, options )
        return
      end

      # now we can preload all associations needed for efficient indexing
      if respond_to?( :load_for_qdrant_index )
        scope = scope.load_for_qdrant_index
      end
      scope.find_in_batches( **options ) do | batch |
        if debug && !batch.empty?
          Rails.logger.info "[INFO #{Time.now}] Starting to index #{name} :: #{batch[0].id}"
        end
        bulk_qdrant_index( batch )
      end
    end

    private

    def delayed_qdrant_index( scope, options )
      # make sure to fetch the results of the scope and store
      # the resulting IDs instead of scopes for DelayedJobs.
      # For example, delayed calls this like are very efficient:
      #   TaxonPhoto.elastic_index!( scope: Taxon.find( 1 ).taxon_photos, delay: true )
      result_ids = scope.order( :id ).pluck( :id )
      return unless result_ids.any?

      id_hash = Digest::MD5.hexdigest( result_ids.join( "," ) )
      queue = if result_ids.size > 50
        "throttled"
      end
      delay(
        unique_hash: { "#{name}::qdrant_index": id_hash },
        queue: queue
      ).qdrant_index!( options.except( :batch_size ).merge( ids: result_ids ) )
    end

    # standard wrapper for bulk indexing with Elasticsearch::Model
    def bulk_qdrant_index( batch )
      batch_to_index = if respond_to?( :prune_batch_for_qdrant_index )
        prune_batch_for_qdrant_index( batch )
      else
        batch
      end
      return if batch_to_index.empty?

      __qdrant__.upsert_points( prepare_for_qdrant_index( batch_to_index ) )
    end

    # map each instance into its indexable form with `qdrant_json`
    def prepare_for_qdrant_index( batch )
      if respond_to?( :prepare_batch_for_qdrant_index )
        prepare_batch_for_qdrant_index( batch )
      end
      batch.map do | obj |
        qdrant_json = obj.as_qdrant_json
        next if qdrant_json.blank?

        qdrant_json
      end.compact
    end
  end

  module InstanceMethods
    def __qdrant__
      @__qdrant__ ||= InstanceMethodsProxy.new( self )
    end

    def qdrant_index!
      if self.class.respond_to?( :prune_batch_for_qdrant_index ) &&
          self.class.prune_batch_for_qdrant_index( [self] ).empty?
        return
      end

      __qdrant__.upsert_point
    end

    def qdrant_delete!
      __qdrant__.delete_point
    end

    private

    # usually called within as_indexed_json to make sure the instance
    # has all associations it needs. It is fast to check even if the
    # associations have been loaded. This should help minimize the number
    # of sql calls needed for non-bulk indexing
    def preload_for_elastic_index
      return unless self.class.respond_to?( :load_for_index )

      self.class.preload_associations(
        self,
        self.class.load_for_index.values[:includes]
      )
    end
  end
end

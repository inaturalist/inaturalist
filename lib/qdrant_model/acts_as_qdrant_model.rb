# frozen_string_literal: true

require "qdrant_model/proxy"

module ActsAsQdrantModel
  class Error < StandardError; end

  def self.included( base )
    base.extend ClassMethods
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
    # page through all instances 200 at a time
    # You can also send options, including scope:
    #   TaxonPhoto.qdrant_index!( batch_size: 20 )
    #   TaxonPhoto.qdrant_index!( scope: TaxonPhoto.where( id: [1,2,3,...] ), batch_size: 20 )
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
      # For example, delayed calls like this are very efficient:
      #   TaxonPhoto.qdrant_index!( scope: Taxon.find( 1 ).taxon_photos, delay: true )
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
  end
end

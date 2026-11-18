# frozen_string_literal: true

module ElasticModel
  # An index served through an alias. For a model with es_index_version set,
  # index_name (e.g. "production_posts") is an alias for the physical index
  # "#{index_name}_v#{es_index_version}", so a mapping change can be built as
  # a new version and swapped in. Reads and writes go through the alias; only
  # creating and deleting the index need this class.
  class AliasedIndex
    class Exists < StandardError; end

    attr_reader :klass

    def initialize( klass )
      @klass = klass.base_class
    end

    def client
      klass.__elasticsearch__.client
    end

    def alias_name
      klass.index_name
    end

    def physical_name
      "#{alias_name}_v#{klass.es_index_version}"
    end

    def exists?
      client.indices.exists_alias( name: alias_name )
    end

    # Creates the physical index and its alias in one request. Never deletes
    # anything: raises Exists if the alias name is already taken by an alias
    # or a concrete index.
    def create!
      raise Exists, exists_message if client.indices.exists( index: alias_name )

      client.indices.create(
        index: physical_name,
        body: {
          settings: klass.settings.to_hash,
          mappings: klass.mappings.to_hash.merge( _meta: { version: klass.es_index_version } ),
          aliases: { alias_name => { is_write_index: true } }
        }
      )
    end

    # Deletes the indices behind the alias, every versioned index, and a
    # concrete index with the alias name. Destroys data; only the rebuild
    # paths use it. Deletes by explicit name because ES 8 rejects wildcard
    # deletes (action.destructive_requires_name).
    def delete!
      index_names_to_delete.each do | name |
        client.indices.delete( index: name )
      end
    end

    private

    def index_names_to_delete
      names = if exists?
        client.indices.get_alias( name: alias_name ).body.keys
      elsif client.indices.exists( index: alias_name )
        [alias_name]
      else
        []
      end
      ( names + client.indices.get( index: "#{alias_name}_v*" ).body.keys ).uniq
    end

    def exists_message
      if exists?
        indices = client.indices.get_alias( name: alias_name ).body.keys
        "#{alias_name} already exists (alias for #{indices.join( ', ' )}). Nothing was changed."
      else
        "#{alias_name} is a concrete index, not an alias. Delete it first, for example with " \
          "rake 'es:recreate_index[#{klass.name}]', which destroys its data. Nothing was changed."
      end
    end
  end
end

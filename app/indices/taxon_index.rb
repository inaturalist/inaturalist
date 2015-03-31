class Taxon < ActiveRecord::Base

  # used to cache place_ids when bulk indexing
  attr_accessor :indexed_place_ids

  acts_as_elastic_model
  scope :load_for_index, -> { includes(:colors, :taxon_names, :taxon_descriptions) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :names do
        indexes :name, index_analyzer: "ascii_snowball_analyzer",
          search_analyzer: "ascii_snowball_analyzer"
        indexes :name_autocomplete, index_analyzer: "autocomplete_analyzer",
          search_analyzer: "standard_analyzer"
      end
    end
  end

  def as_indexed_json(options={})
    preload_for_elastic_index
    json = {
      id: id,
      name: name,
      names: taxon_names.sort_by(&:position).map{ |tn| tn.as_indexed_json(autocomplete: !options[:basic]) },
      rank: rank,
      rank_level: rank_level,
      iconic_taxon_id: iconic_taxon_id,
      ancestor_ids: ((ancestry ? ancestry.split("/").map(&:to_i) : [ ]) << id )
    }
    unless options[:basic]
      json.merge!({
        created_at: created_at,
        colors: colors.map(&:as_indexed_json),
        is_active: is_active,
        ancestry: ancestry,
        observations_count: observations_count,
        # see prepare_for_index. Basicaly indexed_place_ids may be set
        # when using Taxon.elasticindex! to bulk import
        place_ids: (indexed_place_ids || listed_taxa.map(&:place_id)).compact.uniq
      })
    end
    json
  end

  # the following few functions import, prepare_for_index, and
  # bulk_index are for efficient bulk indexing of taxa. The main issue
  # with taxa is to preload place_ids, all the listed_taxa and
  # all their places need to be loaded into AR objects, which is slow.
  def self.elastic_index!
    Taxon.load_for_index.find_in_batches do |taxa|
      bulk_index(taxa)
    end
  end

  def self.prepare_for_index(taxa)
    # this hacky bit of code is to prevent loading every taxon's
    # entire listed_taxa and places into memory during indexing,
    # just to get place_ids. This query fetches the place_ids
    # for each taxa and places them in a attr indexed_place_ids
    taxa_by_id = Hash[ taxa.map{ |t| [ t.id, t ] } ]
    batch_ids_string = taxa_by_id.keys.join(",")
    connection.execute("
      SELECT taxon_id, place_id
      FROM listed_taxa lt
      JOIN places p ON (lt.place_id = p.id)
      WHERE lt.taxon_id IN (#{ batch_ids_string })").to_a.each do |r|
      if t = taxa_by_id[ r["taxon_id"].to_i ]
        t.indexed_place_ids ||= [ ]
        t.indexed_place_ids << r["place_id"].to_i
      end
    end
    taxa.map do |taxon|
      # make sure we default indexed_place_ids = [ ] so we
      # don't have to query the DB later on when its nil
      taxon.indexed_place_ids ||= [ ]
      { index: { _id: taxon.id, data: taxon.as_indexed_json } }
    end
  end

  def self.bulk_index(taxa)
    Taxon.__elasticsearch__.client.bulk({
      index: ::Taxon.__elasticsearch__.index_name,
      type: ::Taxon.__elasticsearch__.document_type,
      body: prepare_for_index(taxa)
    })
  end

end

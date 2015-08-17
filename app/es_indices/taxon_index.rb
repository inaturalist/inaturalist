class Taxon < ActiveRecord::Base

  include ActsAsElasticModel

  # used to cache place_ids when bulk indexing
  attr_accessor :indexed_place_ids

  scope :load_for_index, -> { includes(:colors, :taxon_names, :taxon_descriptions,
    { taxon_photos: :photo }) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :names do
        indexes :name, analyzer: "ascii_snowball_analyzer"
        # NOTE: don't forget to install the proper analyzers in Elasticsearch
        # see https://github.com/elastic/elasticsearch-analysis-kuromoji#japanese-kuromoji-analysis-for-elasticsearch
        indexes :name_ja, analyzer: "kuromoji"
        indexes :name_autocomplete, index_analyzer: "autocomplete_analyzer",
          search_analyzer: "standard_analyzer"
        indexes :name_autocomplete_ja, analyzer: "autocomplete_analyzer_ja"
        indexes :exact, analyzer: "keyword_analyzer"
      end
    end
  end

  def as_indexed_json(options={})
    # Temporary hack to figure out why some taxa are being indexed w/o
    # all taxon_names. Checking indexed_place_ids which will be assigned during
    # bluk indexing, and we're pretty sure the bulk indexing is working OK
    if indexed_place_ids.nil? && !options[:basic]
      begin
        # comparing .count (always runs a COUNT() query) to .length (always
        # selects records and counts them). I suspect some taxa are preloading
        # just some names, and then getting indexed with those names only
        raise "Taxon names out of sync" if taxon_names.count != taxon_names.length
      rescue Exception => e
        Logstasher.write_exception(e, reference: "Taxon.elastic_index! names sync")
        Rails.logger.error "[Warning] Taxon.elastic_index! has a problem: #{ e }"
        Rails.logger.error "Names before reload:\n#{ taxon_names.join("\n") }"
        taxon_names.reload
        Rails.logger.error "Names after reload:\n#{ taxon_names.join("\n") }"
        Rails.logger.error "Backtrace:\n#{ e.backtrace[0..30].join("\n") }\n..."
      end
    end
    json = {
      id: id,
      name: name,
      names: taxon_names.
        sort_by{ |tn| [ tn.is_valid? ? 0 : 1, tn.position, tn.id ] }.
        map{ |tn| tn.as_indexed_json(autocomplete: !options[:basic]) },
      rank: rank,
      rank_level: rank_level,
      iconic_taxon_id: iconic_taxon_id,
      ancestor_ids: ((ancestry ? ancestry.split("/").map(&:to_i) : [ ]) << id ),
      is_active: is_active
    }
    unless options[:basic]
      json.merge!({
        created_at: created_at,
        default_photo_url: default_photo ? default_photo.best_url(:square) : nil,
        colors: colors.map(&:as_indexed_json),
        ancestry: ancestry,
        observations_count: observations_count,
        # see prepare_for_index. Basicaly indexed_place_ids may be set
        # when using Taxon.elasticindex! to bulk import
        place_ids: (indexed_place_ids || listed_taxa.map(&:place_id)).compact.uniq
      })
    end
    json
  end

  # This custom prepare_for_index is used to preload place_ids
  # using a SQL call to avoid loading all the listed_taxa
  # into AR objects. This saves a lot of time when bulk indexing
  def self.prepare_batch_for_index(taxa)
    # make sure we default all caches to empty arrays
    # this prevents future lookups for instances with no results
    taxa.each{ |t| t.indexed_place_ids ||= [ ] }
    taxa_by_id = Hash[ taxa.map{ |t| [ t.id, t ] } ]
    batch_ids_string = taxa_by_id.keys.join(",")
    # fetch all place_ids store them in `indexed_place_ids`
    connection.execute("
      SELECT taxon_id, place_id
      FROM listed_taxa lt
      JOIN places p ON (lt.place_id = p.id)
      WHERE lt.taxon_id IN (#{ batch_ids_string })").to_a.each do |r|
      if t = taxa_by_id[ r["taxon_id"].to_i ]
        t.indexed_place_ids << r["place_id"].to_i
      end
    end
  end

end

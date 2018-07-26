class Taxon < ActiveRecord::Base

  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 500

  # used to cache place_ids when bulk indexing
  attr_accessor :indexed_place_ids

  scope :load_for_index, -> { includes(:colors, :taxon_descriptions, :atlas,
    :taxon_change_taxa, :taxon_schemes, :taxon_changes, :en_wikipedia_description,
    { conservation_statuses: :place },
    { taxon_names: :place_taxon_names },
    { taxon_photos: { photo: [ :user, :flags ] } },
    { listed_taxa_with_means_or_statuses: :place }) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :ancestry, type: "keyword"
      indexes :min_species_ancestry, type: "keyword"
      indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :rank, type: "keyword"
      indexes :wikipedia_url, type: "keyword", index: false
      indexes :taxon_photos do
        indexes :license_code, type: "keyword"
        indexes :photo do
          indexes :attribution, type: "keyword", index: false
          indexes :license_code, type: "keyword"
          indexes :original_url, type: "keyword", index: false
          indexes :large_url, type: "keyword", index: false
          indexes :medium_url, type: "keyword", index: false
          indexes :small_url, type: "keyword", index: false
          indexes :square_url, type: "keyword", index: false
          indexes :url, type: "keyword", index: false
          indexes :native_page_url, type: "keyword", index: false
          indexes :native_photo_id, type: "keyword", index: false
          indexes :type, type: "keyword"
        end
      end
      indexes :colors do
        indexes :value, type: "keyword"
      end
      indexes :default_photo do
        indexes :attribution, type: "keyword", index: false
        indexes :license_code, type: "keyword"
        indexes :medium_url, type: "keyword", index: false
        indexes :square_url, type: "keyword", index: false
        indexes :url, type: "keyword", index: false
      end
      indexes :listed_taxa do
        indexes :establishment_means, type: "keyword"
      end
      indexes :names, type: :nested do
        indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :locale, type: "keyword"
        # NOTE: don't forget to install the proper analyzers in Elasticsearch
        # see https://github.com/elastic/elasticsearch-analysis-kuromoji#japanese-kuromoji-analysis-for-elasticsearch
        indexes :name_ja, type: "text", analyzer: "kuromoji"
        indexes :name_autocomplete, type: "text",
          analyzer: "autocomplete_analyzer",
          search_analyzer: "standard_analyzer"
        indexes :name_autocomplete_ja, type: "text", analyzer: "autocomplete_analyzer_ja"
        indexes :exact, type: "keyword"
        indexes :exact_ci, type: "text", analyzer: "keyword_analyzer"
      end
      indexes :statuses do
        indexes :authority, type: "keyword"
        indexes :geoprivacy, type: "keyword"
        indexes :status, type: "keyword"
      end
    end
  end

  def as_indexed_json(options={})
    if indexed_place_ids.nil? && !options[:for_observation] && !options[:no_details]
      # make sure taxon names are up-to-date
      taxon_names.reload if taxon_names.count != taxon_names.length
    end
    json = {
      id: id,
      name: name,
      rank: rank,
      rank_level: rank_level,
      iconic_taxon_id: iconic_taxon_id,
      parent_id: parent_id,
      ancestor_ids: ((ancestry ? ancestry.split("/").map(&:to_i) : [ ]) << id ),
      is_active: is_active
    }
    # indexing originating from Identifications
    if options[:for_identification]
      if Taxon::LIFE
        json[:ancestor_ids].delete(Taxon::LIFE.id)
      end
      json[:ancestry] = json[:ancestor_ids].join(",")
      json[:min_species_ancestry] = (rank_level && rank_level < RANK_LEVELS["species"]) ?
        json[:ancestor_ids][0...-1].join(",") : json[:ancestry]
      unless options[:for_observation]
        json[:min_species_ancestors] = json[:min_species_ancestry].split(",").
          map{ |aid| { id: aid.to_i } }
      end
    else
      json[:ancestry] = json[:ancestor_ids].join(",")
      json[:min_species_ancestry] = (rank_level && rank_level < RANK_LEVELS["species"]) ?
        json[:ancestor_ids][0...-1].join(",") : json[:ancestry]
    end
    # indexing originating Observations, not via another model
    unless options[:no_details]
      json[:names] = taxon_names.
        sort_by{ |tn| [ tn.is_valid? ? 0 : 1, tn.position, tn.id ] }.
        map{ |tn| tn.as_indexed_json(autocomplete: !options[:for_observation]) }
      json[:statuses] = conservation_statuses.map(&:as_indexed_json)
      json[:extinct] = conservation_statuses.select{|cs| cs.place_id.blank? && cs.iucn == Taxon::IUCN_EXTINCT }.size > 0
    end
    # indexing originating from Taxa
    unless options[:for_observation] || options[:no_details]
      flag_counts = flags.group( :resolved ).count
      json.merge!({
        created_at: created_at,
        default_photo: default_photo ?
          default_photo.as_indexed_json(sizes: [ :square, :medium ]) : nil,
        colors: colors.map(&:as_indexed_json),
        ancestry: ancestry,
        taxon_changes_count: taxon_changes_count,
        taxon_schemes_count: taxon_schemes_count,
        observations_count: observations_count,
        flag_counts: {
          resolved: flag_counts[true] || 0,
          unresolved: flag_counts[false] || 0
        },
        current_synonymous_taxon_ids: is_active? ? nil : current_synonymous_taxa.map(&:id),
        # see prepare_for_index. Basicaly indexed_place_ids may be set
        # when using Taxon.elasticindex! to bulk import
        place_ids: (indexed_place_ids || listed_taxa.map(&:place_id)).compact.uniq,
        listed_taxa: listed_taxa_with_means_or_statuses.map(&:as_indexed_json),
        taxon_photos: taxon_photos_with_backfill(limit: 30, skip_external: true).
          select{ |tp| !tp.photo.blank? }.map(&:as_indexed_json),
        atlas_id: atlas.try( :id ),
        complete_species_count: complete_species_count,
        wikipedia_url: en_wikipedia_description ? en_wikipedia_description.url : nil
      })
      if complete_taxon
        json[:complete_rank] = complete_taxon.complete_rank
        json[:complete_rank] = Taxon::SPECIES if json[:complete_rank].blank?
      end
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

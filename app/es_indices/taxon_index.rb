class Taxon < ApplicationRecord

  include ActsAsElasticModel

  DEFAULT_ES_BATCH_SIZE = 500

  # used to cache place_ids when bulk indexing
  attr_accessor :indexed_place_ids

  scope :load_for_index, -> { includes(:colors, :taxon_descriptions, :atlas,
    :taxon_framework, :flags,
    :taxon_change_taxa, :taxon_schemes, :taxon_changes, :en_wikipedia_description,
    { conservation_statuses: :place },
    { taxon_names: :place_taxon_names },
    { taxon_photos: { photo: [
      :user,
      :flags,
      :file_extension,
      :file_prefix
    ] } },
    { listed_taxa_with_means_or_statuses: :place }) }
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :ancestor_ids, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :ancestry, type: "keyword"
      indexes :atlas_id, type: "integer"
      indexes :colors do
        indexes :id, type: "byte", index: false
        indexes :value, type: "keyword", index: false
      end
      indexes :complete_rank, type: "keyword"
      indexes :complete_species_count, type: "integer"
      indexes :created_at, type: "date"
      indexes :current_synonymous_taxon_ids, type: "integer"
      indexes :default_photo do
        indexes :attribution, type: "keyword", index: false
        indexes :flags do
          indexes :comment, type: "keyword", index: false
          indexes :created_at, type: "date", index: false
          indexes :flag, type: "keyword", index: false
          indexes :id, type: "integer", index: false
          indexes :resolved, type: "boolean", index: false
          indexes :resolver_id, type: "integer", index: false
          indexes :updated_at, type: "date", index: false
          indexes :user_id, type: "integer", index: false
        end
        indexes :id, type: "integer"
        indexes :license_code, type: "keyword", index: false
        indexes :medium_url, type: "keyword", index: false
        indexes :original_dimensions do
          indexes :height, type: "short", index: false
          indexes :width, type: "short", index: false
        end
        indexes :square_url, type: "keyword", index: false
        indexes :url, type: "keyword", index: false
      end
      indexes :extinct, type: "boolean"
      indexes :flag_counts do
        indexes :resolved, type: "short", index: false
        indexes :unresolved, type: "short", index: false
      end
      indexes :iconic_taxon_id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :is_active, type: "boolean"
      indexes :listed_taxa do
        indexes :establishment_means, type: "keyword", index: false
        indexes :id, type: "integer", index: false
        indexes :occurrence_status_level, type: "byte", index: false
        indexes :place_id, type: "integer", index: false
        indexes :user_id, type: "integer", index: false
      end
      indexes :min_species_ancestry, type: "keyword"
      indexes :min_species_taxon_id, type: "integer"
      indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
      indexes :names, type: :nested do
        indexes :exact, type: "keyword"
        indexes :exact_ci, type: "text", analyzer: "keyword_analyzer"
        indexes :is_valid, type: "boolean"
        indexes :locale, type: "keyword"
        indexes :name, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :name_autocomplete, type: "text",
          analyzer: "autocomplete_analyzer",
          search_analyzer: "standard_analyzer"
        indexes :name_autocomplete_ja, type: "text", analyzer: "autocomplete_analyzer_ja"
        # NOTE: don't forget to install the proper analyzers in Elasticsearch
        # see https://github.com/elastic/elasticsearch-analysis-kuromoji#japanese-kuromoji-analysis-for-elasticsearch
        indexes :name_ja, type: "text", analyzer: "kuromoji"
        indexes :place_taxon_names do
          indexes :place_id, type: "integer"
          indexes :position, type: "short"
        end
        indexes :position, type: "short"
      end
      indexes :observations_count, type: "integer"
      indexes :parent_id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :photos_locked, type: "boolean", index: false
      indexes :place_ids, type: "integer"
      indexes :rank, type: "keyword"
      indexes :rank_level, type: "scaled_float", scaling_factor: 100
      indexes :statuses do
        indexes :authority, type: "keyword"
        indexes :geoprivacy, type: "keyword"
        indexes :iucn, type: "byte"
        indexes :place_id, type: "integer"
        indexes :user_id, type: "integer"
        indexes :source_id, type: "short"
        indexes :status, type: "keyword"
        indexes :status_name, type: "keyword"
      end
      indexes :taxon_changes_count, type: "byte"
      indexes :taxon_photos do
        indexes :license_code, type: "keyword", index: false
        indexes :photo do
          indexes :attribution, type: "keyword", index: false
          indexes :flags do
            indexes :comment, type: "keyword", index: false
            indexes :created_at, type: "date", index: false
            indexes :flag, type: "keyword", index: false
            indexes :id, type: "integer", index: false
            indexes :resolved, type: "boolean", index: false
            indexes :resolver_id, type: "integer", index: false
            indexes :updated_at, type: "date", index: false
            indexes :user_id, type: "integer", index: false
          end
          indexes :id, type: "integer"
          indexes :large_url, type: "keyword", index: false
          indexes :license_code, type: "keyword", index: false
          indexes :medium_url, type: "keyword", index: false
          indexes :native_page_url, type: "keyword", index: false
          indexes :native_photo_id, type: "keyword", index: false
          indexes :original_dimensions do
            indexes :height, type: "short", index: false
            indexes :width, type: "short", index: false
          end
          indexes :original_url, type: "keyword", index: false
          indexes :small_url, type: "keyword", index: false
          indexes :square_url, type: "keyword", index: false
          indexes :url, type: "keyword", index: false
          indexes :type, type: "keyword", index: false
        end
        indexes :taxon_id, type: "integer", index: false
      end
      indexes :taxon_schemes_count, type: "byte"
      indexes :universal_search_rank, type: "integer"
      indexes :uuid, type: "keyword"
      indexes :wikipedia_url, type: "keyword", index: false
    end
  end

  def as_indexed_json(options={})
    if indexed_place_ids.nil? && !options[:for_observation] && !options[:no_details]
      # make sure taxon names are up-to-date
      taxon_names.reload if taxon_names.count != taxon_names.length
    end
    json = {
      id: id,
      rank: rank,
      rank_level: rank_level,
      iconic_taxon_id: iconic_taxon_id,
      ancestor_ids: ((ancestry ? ancestry.split("/").map(&:to_i) : [ ]) << id ),
      is_active: is_active,
      min_species_taxon_id: (rank_level && rank_level < RANK_LEVELS["species"]) ?
        parent_id : id
    }
    # min_species_* below means don't consider any ranks more specific than species.
    # If the taxon is a subspecies, its min_species_ancestry stops at species
    # and its min_species_taxon_id is the ID of its parent, the species.
    # These are used in Elasticsearch aggregations, for example leaf counts

    # indexing originating from Identifications
    if options[:for_identification]
      if Taxon::LIFE
        json[:ancestor_ids].delete(Taxon::LIFE.id)
      end
      json[:min_species_ancestry] = (rank_level && rank_level < RANK_LEVELS["species"]) ?
        json[:ancestor_ids][0...-1].join(",") : json[:ancestor_ids].join(",")
    else
      json[:name] = name
      json[:parent_id] = parent_id
      json[:ancestry] = json[:ancestor_ids].join(",")
      json[:min_species_ancestry] = (rank_level && rank_level < RANK_LEVELS["species"]) ?
        json[:ancestor_ids][0...-1].join(",") : json[:ancestry]
    end
    # indexing originating Observations, not via another model
    unless options[:no_details]
      unless options[:for_observation]
        json[:names] = taxon_names.
          sort_by{ |tn| [ tn.is_valid? ? 0 : 1, tn.position, tn.id ] }.
          map{ |tn| tn.as_indexed_json(autocomplete: !options[:for_observation]) }
      end
      json[:statuses] = conservation_statuses.map(&:as_indexed_json)
      json[:extinct] = conservation_statuses.select{|cs| cs.place_id.blank? && cs.iucn == Taxon::IUCN_EXTINCT }.size > 0
    end
    # indexing originating from Taxa
    unless options[:for_observation] || options[:no_details]
      flag_counts = Hash[flags.group_by{ |t| t.resolved }.map{ |k,v| [k, v.length] }]
      json.merge!({
        created_at: created_at,
        default_photo: default_photo ?
          default_photo.as_indexed_json(sizes: [ :square, :medium ]) : nil,
        colors: colors.map(&:as_indexed_json),
        ancestry: ancestry,
        taxon_changes_count: taxon_changes_count,
        taxon_schemes_count: taxon_schemes_count,
        observations_count: observations_count,
        photos_locked: photos_locked,
        universal_search_rank: observations_count,
        flag_counts: {
          resolved: flag_counts[true] || 0,
          unresolved: flag_counts[false] || 0
        },
        current_synonymous_taxon_ids: is_active? ? nil : current_synonymous_taxa.map(&:id),
        # see prepare_for_index. Basicaly indexed_place_ids may be set
        # when using Taxon.elasticindex! to bulk import
        place_ids: (indexed_place_ids || listed_taxa.map(&:place_id)).compact.uniq,
        listed_taxa: listed_taxa_with_means_or_statuses.map(&:as_indexed_json),
        taxon_photos: taxon_photos.select{ |tp| !tp.photo.blank? }.map(&:as_indexed_json),
        atlas_id: atlas.try( :id ),
        complete_species_count: complete_species_count,
        wikipedia_url: en_wikipedia_description ? en_wikipedia_description.url : nil
      })
      if taxon_framework = get_complete_taxon_framework_for_internode_or_root
        json[:complete_rank] = Taxon::RANK_FOR_RANK_LEVEL[taxon_framework.rank_level]
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

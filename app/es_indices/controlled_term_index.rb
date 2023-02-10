class ControlledTerm < ApplicationRecord

  include ActsAsElasticModel

  scope :load_for_index, -> { includes({ values: [ :values, :labels, :controlled_term_taxa ] }, :labels, :controlled_term_taxa, :attrs) }

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :blocking, type: "boolean"
      indexes :excepted_taxon_ids, type: "integer"
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :is_value, type: "boolean"
      indexes :labels do
        indexes :definition, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :id, type: "integer"
        indexes :label, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :locale, type: "keyword"
        indexes :valid_within_clade, type: "integer"
      end
      indexes :multivalues, type: "boolean"
      indexes :ontology_uri, type: "keyword", index: false
      indexes :taxon_ids, type: "keyword"
      indexes :uri, type: "keyword", index: false
      indexes :uuid, type: "keyword"
      indexes :values do
        indexes :blocking, type: "boolean"
        indexes :excepted_taxon_ids, type: "integer"
        indexes :id, type: "integer"
        indexes :labels do
          indexes :definition, type: "text", analyzer: "ascii_snowball_analyzer"
          indexes :id, type: "integer"
          indexes :label, type: "text", analyzer: "ascii_snowball_analyzer"
          indexes :locale, type: "keyword"
          indexes :valid_within_clade, type: "integer"
        end
        indexes :ontology_uri, type: "keyword", index: false
        indexes :taxon_ids, type: "keyword"
        indexes :uuid, type: "keyword"
        indexes :uri, type: "keyword", index: false
      end
    end
  end

  def as_indexed_json(options={})
    return { } unless active?
    preload_for_elastic_index unless options[:is_value]
    fields_to_remove = [ "user_id", "active", "created_at", "updated_at"]
    if options[:is_value]
      fields_to_remove << "is_value"
    end
    if is_value?
      fields_to_remove << "multivalued"
    else
      fields_to_remove << "blocking"
    end
    # splatten out the array with *
    json = self.attributes.except(*fields_to_remove)
    if values.length > 0
      json[:values] = values.select(&:active).map{ |v| v.as_indexed_json(is_value: true) }
    end
    json[:labels] = labels.map{ |l|
      l.attributes.except(
        "controlled_term_id",
        "user_id",
        "icon_file_name",
        "icon_content_type",
        "icon_file_size",
        "icon_updated_at",
        "created_at",
        "updated_at"
      )
    }
    controlled_term_taxa.each do |ctt|
      if ctt.exception
        json[:excepted_taxon_ids] ||= []
        json[:excepted_taxon_ids] << ctt.taxon_id unless json[:excepted_taxon_ids].include?( ctt.taxon_id )
      else
        json[:taxon_ids] ||= []
        json[:taxon_ids] << ctt.taxon_id unless json[:taxon_ids].include?( ctt.taxon_id )
      end
    end
    json
  end


end

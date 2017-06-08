class ControlledTerm < ActiveRecord::Base

  include ActsAsElasticModel

  scope :load_for_index, -> { includes({ values: [ :values, :labels ] }, :labels) }

  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings(dynamic: true) do
      indexes :id, type: "integer"
      indexes :uuid, type: "keyword"
      indexes :ontology_uri, type: "keyword", index: false
      indexes :uri, type: "keyword", index: false
      indexes :labels do
        indexes :definition, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :label, type: "text", analyzer: "ascii_snowball_analyzer"
        indexes :locale, type: "keyword"
      end
      indexes :values do
        indexes :id, type: "integer"
        indexes :uuid, type: "keyword"
        indexes :ontology_uri, type: "keyword", index: false
        indexes :uri, type: "keyword", index: false
        indexes :labels do
          indexes :definition, type: "text", analyzer: "ascii_snowball_analyzer"
          indexes :label, type: "text", analyzer: "ascii_snowball_analyzer"
          indexes :locale, type: "keyword"
        end
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
    end
    # splatten out the array with *
    json = self.attributes.except(*fields_to_remove)
    if values.length > 0
      json[:values] = values.map{ |v| v.as_indexed_json(is_value: true) }
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
    json
  end


end

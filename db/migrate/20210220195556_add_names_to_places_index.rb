class AddNamesToPlacesIndex < ActiveRecord::Migration
  def up
    Place.__elasticsearch__.client.indices.put_mapping(
      index: Place.index_name,
      body: {
        properties: {
          names: {
            type: "nested",
            properties: {
              exact: { type: "keyword" },
              exact_ci: { type: "text", analyzer: "keyword_analyzer" },
              locale: { type: "keyword" },
              name: { type: "text", analyzer: "ascii_snowball_analyzer" },
              name_autocomplete: { type: "text", analyzer: "autocomplete_analyzer", search_analyzer: "standard_analyzer" },
              name_autocomplete_ja: { type: "text", analyzer: "autocomplete_analyzer_ja" },
              name_ja: { type: "text", analyzer: "kuromoji" }
            }
          }
        }
      }
    )
  end

  def down
    say "This migration is irreversible"
  end
end

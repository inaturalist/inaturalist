class AddExactNameCiToTaxonIndex < ActiveRecord::Migration
  def up
    options = {
      index: Taxon.index_name,
      type: Taxon.document_type,
      body: { }
    }
    options[:body][Taxon.document_type] = {
      properties: {
        names: {
          properties: {
            exact_ci: {
              type: "text",
              analyzer: "keyword_analyzer"
            }
          }
        }
      }
    }
    Taxon.__elasticsearch__.client.indices.put_mapping(options)
  end

  def down
    # irreversible
  end
end

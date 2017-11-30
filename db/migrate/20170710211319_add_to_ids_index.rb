class AddToIdsIndex < ActiveRecord::Migration
  def up
    options = {
      index: Identification.index_name,
      type: Identification.document_type,
      body: { }
    }
    options[:body][Identification.document_type] = {
      properties: {
        taxon_change: {
          properties: {
            type: { type: "keyword" }
          }
        },
        flags: {
          properties: {
            flag: { type: "keyword" }
          }
        }
      }
    }
    Identification.__elasticsearch__.client.indices.put_mapping(options)
  end

  def down
    # irreversible
  end
end

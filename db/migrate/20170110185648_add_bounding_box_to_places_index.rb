class AddBoundingBoxToPlacesIndex < ActiveRecord::Migration
  def up
    Place.__elasticsearch__.client.indices.put_mapping(
      index: Place.index_name,
      type: Place.document_type,
      body: {
        Place.document_type => {
          properties: {
            bounding_box_geojson: {
              type: "geo_shape"
            }
          }
        }
      }
    )
  end

  def down
    # There IS no return
  end
end

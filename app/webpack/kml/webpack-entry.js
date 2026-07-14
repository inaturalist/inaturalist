// Exposes KML/KMZ -> GeoJSON conversion to the legacy Sprockets asset
// pipeline (see addKmlAssets in app/assets/javascripts/inaturalist/map3.js.erb)
window.KmlAssets = require( "./kml_to_geojson" );

const toGeoJSON = require( "@tmcw/togeojson" );
const JSZip = require( "jszip" );
const sanitizeHtml = require( "sanitize-html" );

function kmlTextToGeoJSON( kmlText ) {
  const dom = new DOMParser( ).parseFromString( kmlText, "application/xml" );
  if ( dom.querySelector( "parsererror" ) ) {
    throw new Error( "Could not parse KML" );
  }
  const geojson = toGeoJSON.kml( dom, { skipNullGeometry: true } );
  geojson.features = geojson.features.reverse( );
  geojson.features.forEach( ( feature, index ) => {
    if ( feature.id ) {
      feature.properties.kml_id = feature.id;
    }
    feature.id = `kml-feature-${index}`;
  } );

  return geojson;
}

function kmzToKmlText( arrayBuffer ) {
  return JSZip.loadAsync( arrayBuffer ).then( zip => {
    const kmlFiles = zip.file( /\.kml$/i );
    const docFile = kmlFiles.filter( f => f.name.toLowerCase( ) === "doc.kml" )[0]
      || kmlFiles[0];
    if ( !docFile ) {
      throw new Error( "KMZ archive contains no KML file" );
    }
    return docFile.async( "string" );
  } );
}

function fetchGeoJSON( url ) {
  const isKmz = /\.kmz([?#]|$)/i.test( url );
  return fetch( url ).then( response => {
    if ( !response.ok ) {
      throw new Error( `Failed to fetch ${url}: ${response.status}` );
    }
    return isKmz
      ? response.arrayBuffer( ).then( kmzToKmlText )
      : response.text( );
  } ).then( kmlTextToGeoJSON );
}

function sanitizeDescription( description ) {
  if ( !description ) { return ""; }
  const html = typeof ( description ) === "object" ? description.value : description;
  return sanitizeHtml( String( html ), {
    allowedTags: sanitizeHtml.defaults.allowedTags.concat( ["img"] ),
    allowedAttributes: {
      ...sanitizeHtml.defaults.allowedAttributes,
      img: ["src", "alt", "width", "height"]
    },
    allowedSchemes: ["http", "https", "mailto"]
  } );
}

module.exports = {
  kmlTextToGeoJSON,
  kmzToKmlText,
  fetchGeoJSON,
  sanitizeDescription
};

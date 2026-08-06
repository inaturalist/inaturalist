// Fetches user-uploaded KML/KMZ project assets and converts them to GeoJSON
// for rendering with google.maps.Data, replacing the deprecated
// google.maps.KmlLayer (WEB-1009)
const toGeoJSON = require( "@tmcw/togeojson" );
const JSZip = require( "jszip" );
const sanitizeHtml = require( "sanitize-html" );

function kmlTextToGeoJSON( kmlText ) {
  const dom = new DOMParser( ).parseFromString( kmlText, "application/xml" );
  if ( dom.querySelector( "parsererror" ) ) {
    throw new Error( "Could not parse KML" );
  }
  return toGeoJSON.kml( dom );
}

// KMZ is a zip archive whose main document is conventionally doc.kml at the
// root, but any single .kml entry is accepted by Google Earth
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

// KmlLayer sanitized Placemark description balloons on Google's side, so
// descriptions must be sanitized here before injecting into an InfoWindow.
// togeojson represents HTML (CDATA) descriptions as { "@type": "html", value: ... }
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

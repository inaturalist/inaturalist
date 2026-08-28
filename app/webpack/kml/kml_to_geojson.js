const toGeoJSON = require( "@tmcw/togeojson" );
const JSZip = require( "jszip" );
const sanitizeHtml = require( "sanitize-html" );

function childText( el, tagName ) {
  const child = el.getElementsByTagNameNS( "*", tagName )[0];
  return child ? child.textContent.trim( ) : null;
}

function xyAttrs( el, tagName ) {
  const child = el.getElementsByTagNameNS( "*", tagName )[0];
  if ( !child ) { return null; }
  return {
    x: parseFloat( child.getAttribute( "x" ) ),
    y: parseFloat( child.getAttribute( "y" ) ),
    xunits: child.getAttribute( "xunits" ) || "fraction",
    yunits: child.getAttribute( "yunits" ) || "fraction"
  };
}

// KML screen coordinates originate at the bottom left; pixels measure from
// the left/bottom edges and insetPixels from the right/top edges
function axisBucket( value, units ) {
  if ( units === "pixels" ) { return "low"; }
  if ( units === "insetPixels" ) { return "high"; }
  if ( value < 1 / 3 ) { return "low"; }
  if ( value > 2 / 3 ) { return "high"; }
  return "center";
}

// Snap a KML screenXY to one of the google.maps.ControlPosition slots, the
// migration guide's prescribed replacement for ScreenOverlay positioning
function screenOverlayControlPosition( screenXY ) {
  if ( !screenXY || Number.isNaN( screenXY.x ) || Number.isNaN( screenXY.y ) ) {
    return "RIGHT_BOTTOM";
  }
  const grid = {
    "low,high": "TOP_LEFT",
    "center,high": "TOP_CENTER",
    "high,high": "TOP_RIGHT",
    "low,center": "LEFT_CENTER",
    "center,center": "BOTTOM_CENTER",
    "high,center": "RIGHT_CENTER",
    "low,low": "BOTTOM_LEFT",
    "center,low": "BOTTOM_CENTER",
    "high,low": "RIGHT_BOTTOM"
  };
  const horizontal = axisBucket( screenXY.x, screenXY.xunits );
  const vertical = axisBucket( screenXY.y, screenXY.yunits );
  return grid[`${horizontal},${vertical}`];
}

// togeojson only converts geometry features, so ScreenOverlays (screen-fixed
// legend images, which KmlLayer rendered) are extracted from the DOM here
function extractScreenOverlays( dom ) {
  const overlays = [];
  const els = dom.getElementsByTagNameNS( "*", "ScreenOverlay" );
  Array.from( els ).forEach( el => {
    if ( childText( el, "visibility" ) === "0" ) { return; }
    const iconEl = el.getElementsByTagNameNS( "*", "Icon" )[0];
    const iconHref = iconEl && childText( iconEl, "href" );
    if ( !iconHref ) { return; }
    const overlay = {
      name: childText( el, "name" ),
      iconHref,
      position: screenOverlayControlPosition( xyAttrs( el, "screenXY" ) )
    };
    const size = xyAttrs( el, "size" );
    if ( size ) {
      if ( size.xunits === "pixels" && size.x > 0 ) { overlay.width = size.x; }
      if ( size.yunits === "pixels" && size.y > 0 ) { overlay.height = size.y; }
    }
    overlays.push( overlay );
  } );
  return overlays;
}

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
  // a foreign member, which google.maps.Data.addGeoJson ignores
  geojson.screenOverlays = extractScreenOverlays( dom );

  return geojson;
}

function kmzToKml( arrayBuffer ) {
  return JSZip.loadAsync( arrayBuffer ).then( zip => {
    const kmlFiles = zip.file( /\.kml$/i );
    const docFile = kmlFiles.filter( f => f.name.toLowerCase( ) === "doc.kml" )[0]
      || kmlFiles[0];
    if ( !docFile ) {
      throw new Error( "KMZ archive contains no KML file" );
    }
    return docFile.async( "string" ).then( kmlText => ( { kmlText, zip } ) );
  } );
}

// KMZ ScreenOverlay icons usually live inside the archive; loose KML may use
// hrefs relative to its own URL. Anything that isn't http(s) is dropped.
function resolveScreenOverlayIcons( overlays, baseUrl, zip ) {
  return Promise.all( ( overlays || [] ).map( overlay => {
    const href = overlay.iconHref;
    const zipEntry = zip
      && ( zip.file( href ) || zip.file( href.replace( /^\.\//, "" ) ) );
    if ( zipEntry ) {
      return zipEntry.async( "blob" )
        .then( blob => ( { ...overlay, iconUrl: URL.createObjectURL( blob ) } ) );
    }
    try {
      const url = new URL( href, new URL( baseUrl || "", window.location.href ) );
      if ( url.protocol === "http:" || url.protocol === "https:" ) {
        return Promise.resolve( { ...overlay, iconUrl: url.href } );
      }
    } catch ( e ) {
      // unresolvable href, fall through to null
    }
    return Promise.resolve( null );
  } ) ).then( resolved => resolved.filter( Boolean ) );
}

function fetchGeoJSON( url ) {
  const isKmz = /\.kmz([?#]|$)/i.test( url );
  return fetch( url ).then( response => {
    if ( !response.ok ) {
      throw new Error( `Failed to fetch ${url}: ${response.status}` );
    }
    return isKmz
      ? response.arrayBuffer( ).then( kmzToKml )
      : response.text( ).then( kmlText => ( { kmlText, zip: null } ) );
  } ).then( ( { kmlText, zip } ) => {
    const geojson = kmlTextToGeoJSON( kmlText );
    return resolveScreenOverlayIcons( geojson.screenOverlays, url, zip )
      .then( screenOverlays => {
        geojson.screenOverlays = screenOverlays;
        return geojson;
      } );
  } );
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
  kmzToKml,
  fetchGeoJSON,
  sanitizeDescription,
  screenOverlayControlPosition,
  resolveScreenOverlayIcons
};

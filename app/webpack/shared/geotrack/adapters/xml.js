// XML helpers that only rely on the DOM Level 2 API, so they work with the
// browser's DOMParser and with @xmldom/xmldom in Node / React Native

function defaultParseXml( xmlString ) {
  if ( typeof DOMParser === "undefined" ) {
    throw new Error( "No DOMParser available; pass parseXml" );
  }
  return new DOMParser( ).parseFromString( xmlString, "application/xml" );
}

// Elements matching a local name in any namespace
export function byName( node, localName ) {
  return Array.from( node.getElementsByTagNameNS( "*", localName ) );
}

export function parseXmlDocument( xmlString, parseXml = defaultParseXml ) {
  let doc;
  try {
    doc = parseXml( xmlString );
  } catch ( e ) {
    throw new Error( "Invalid XML" );
  }
  if ( !doc || !doc.documentElement || byName( doc, "parsererror" ).length > 0 ) {
    throw new Error( "Invalid XML" );
  }
  return doc;
}

export function childText( node, localName ) {
  const el = byName( node, localName )[0];
  return el ? el.textContent.trim( ) : null;
}

export function parseTimeMs( str ) {
  if ( !str ) return NaN;
  return Date.parse( str );
}

const JSZip = require( "jszip" );
const kmlAssets = require( "./kml_to_geojson" );

const SIMPLE_KML = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>Study Area</name>
      <description><![CDATA[<b>Our</b> study area]]></description>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
              -122.5,37.7,0 -122.5,37.9,0 -122.3,37.9,0 -122.3,37.7,0 -122.5,37.7,0
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>`;

const STYLED_KML = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Style id="redPoly">
      <LineStyle>
        <color>ff0000ff</color>
        <width>3</width>
      </LineStyle>
      <PolyStyle>
        <color>7f0000ff</color>
      </PolyStyle>
    </Style>
    <Placemark>
      <name>Styled</name>
      <styleUrl>#redPoly</styleUrl>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>0,0,0 0,1,0 1,1,0 1,0,0 0,0,0</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>`;

const MULTI_GEOMETRY_KML = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Placemark>
    <name>Two Parts</name>
    <MultiGeometry>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>0,0,0 0,1,0 1,1,0 1,0,0 0,0,0</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
      <Point><coordinates>2,2,0</coordinates></Point>
    </MultiGeometry>
  </Placemark>
</kml>`;

describe( "kmlTextToGeoJSON", ( ) => {
  it( "converts a simple Placemark to a Feature with name and description", ( ) => {
    const geojson = kmlAssets.kmlTextToGeoJSON( SIMPLE_KML );
    expect( geojson.type ).toEqual( "FeatureCollection" );
    expect( geojson.features.length ).toEqual( 1 );
    const feature = geojson.features[0];
    expect( feature.geometry.type ).toEqual( "Polygon" );
    expect( feature.properties.name ).toEqual( "Study Area" );
    // togeojson represents HTML CDATA descriptions as a typed-value object
    expect( kmlAssets.sanitizeDescription( feature.properties.description ) )
      .toEqual( "<b>Our</b> study area" );
    expect( feature.geometry.coordinates[0][0] ).toEqual( [-122.5, 37.7, 0] );
  } );

  it( "translates KML styles into simplestyle properties", ( ) => {
    const geojson = kmlAssets.kmlTextToGeoJSON( STYLED_KML );
    const props = geojson.features[0].properties;
    // KML colors are aabbggrr, so ff0000ff is opaque red
    expect( props.stroke ).toEqual( "#ff0000" );
    expect( props["stroke-width"] ).toEqual( 3 );
    expect( props.fill ).toEqual( "#ff0000" );
    expect( props["fill-opacity"] ).toBeCloseTo( 0.5, 1 );
  } );

  it( "handles MultiGeometry", ( ) => {
    const geojson = kmlAssets.kmlTextToGeoJSON( MULTI_GEOMETRY_KML );
    expect( geojson.features.length ).toEqual( 1 );
    expect( geojson.features[0].geometry.type ).toEqual( "GeometryCollection" );
    expect( geojson.features[0].geometry.geometries.length ).toEqual( 2 );
  } );

  it( "throws on unparseable KML", ( ) => {
    expect( ( ) => kmlAssets.kmlTextToGeoJSON( "<kml><unclosed" ) ).toThrow( );
  } );
} );

describe( "kmzToKmlText", ( ) => {
  it( "extracts doc.kml from a KMZ archive", async ( ) => {
    const zip = new JSZip( );
    zip.file( "other.kml", "<kml></kml>" );
    zip.file( "doc.kml", SIMPLE_KML );
    const buffer = await zip.generateAsync( { type: "arraybuffer" } );
    const kmlText = await kmlAssets.kmzToKmlText( buffer );
    expect( kmlText ).toEqual( SIMPLE_KML );
  } );

  it( "falls back to the first KML entry when there is no doc.kml", async ( ) => {
    const zip = new JSZip( );
    zip.file( "something.kml", SIMPLE_KML );
    zip.file( "images/icon.png", "not kml" );
    const buffer = await zip.generateAsync( { type: "arraybuffer" } );
    const kmlText = await kmlAssets.kmzToKmlText( buffer );
    expect( kmlText ).toEqual( SIMPLE_KML );
  } );

  it( "rejects when the archive contains no KML", async ( ) => {
    const zip = new JSZip( );
    zip.file( "readme.txt", "nothing here" );
    const buffer = await zip.generateAsync( { type: "arraybuffer" } );
    await expect( kmlAssets.kmzToKmlText( buffer ) ).rejects.toThrow( /no KML/ );
  } );
} );

describe( "fetchGeoJSON", ( ) => {
  afterEach( ( ) => {
    delete global.fetch;
  } );

  it( "fetches and converts a KML URL", async ( ) => {
    global.fetch = jest.fn( ).mockResolvedValue( {
      ok: true,
      text: ( ) => Promise.resolve( SIMPLE_KML )
    } );
    const geojson = await kmlAssets.fetchGeoJSON( "/attachments/project_assets/1-area.kml" );
    expect( geojson.features[0].properties.name ).toEqual( "Study Area" );
  } );

  it( "fetches and converts a KMZ URL", async ( ) => {
    const zip = new JSZip( );
    zip.file( "doc.kml", SIMPLE_KML );
    const buffer = await zip.generateAsync( { type: "arraybuffer" } );
    global.fetch = jest.fn( ).mockResolvedValue( {
      ok: true,
      arrayBuffer: ( ) => Promise.resolve( buffer )
    } );
    const geojson = await kmlAssets.fetchGeoJSON( "/attachments/project_assets/1-area.kmz" );
    expect( geojson.features[0].properties.name ).toEqual( "Study Area" );
  } );

  it( "rejects on a failed response", async ( ) => {
    global.fetch = jest.fn( ).mockResolvedValue( { ok: false, status: 404 } );
    await expect( kmlAssets.fetchGeoJSON( "/missing.kml" ) ).rejects.toThrow( /404/ );
  } );
} );

describe( "sanitizeDescription", ( ) => {
  it( "strips script tags but keeps formatting and images", ( ) => {
    const dirty = "<b>hi</b><script>alert(1)</script>"
      + "<img src=\"https://example.com/a.png\">"
      + "<img src=\"javascript:alert(1)\">"; // eslint-disable-line no-script-url
    const clean = kmlAssets.sanitizeDescription( dirty );
    expect( clean ).toMatch( "<b>hi</b>" );
    expect( clean ).not.toMatch( "script" );
    expect( clean ).toMatch( "https://example.com/a.png" );
    expect( clean ).not.toMatch( "javascript:" ); // eslint-disable-line no-script-url
  } );

  it( "strips event handler attributes", ( ) => {
    const clean = kmlAssets.sanitizeDescription( "<a href=\"https://example.com\" onclick=\"evil()\">x</a>" );
    expect( clean ).toMatch( "href" );
    expect( clean ).not.toMatch( "onclick" );
  } );
} );

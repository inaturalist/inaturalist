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

// Mirrors ArcGIS-exported trail KML: repeated <Folder id="FeatureLayer0">
// elements whose Placemark ids overlap between folders (e.g. two different
// features both with id="ID_00000")
const DUPLICATE_ID_KML = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Folder id="FeatureLayer0">
      <name>Layer One</name>
      <Placemark id="ID_00000">
        <name>Tidelands Trail</name>
        <MultiGeometry>
          <LineString><coordinates>-122.1,37.5,0 -122.2,37.6,0</coordinates></LineString>
          <LineString><coordinates>-122.3,37.7,0 -122.4,37.8,0</coordinates></LineString>
        </MultiGeometry>
      </Placemark>
      <Placemark id="ID_00001">
        <name>Marsh Trail</name>
        <LineString><coordinates>-122.5,37.9,0 -122.6,38.0,0</coordinates></LineString>
      </Placemark>
    </Folder>
    <Folder id="FeatureLayer0">
      <name>Layer Two</name>
      <Placemark id="ID_00000">
        <name>Bay View Trail</name>
        <LineString><coordinates>-121.1,36.5,0 -121.2,36.6,0</coordinates></LineString>
      </Placemark>
      <Placemark id="ID_00001">
        <name>Ridge Trail</name>
        <LineString><coordinates>-121.3,36.7,0 -121.4,36.8,0</coordinates></LineString>
      </Placemark>
    </Folder>
  </Document>
</kml>`;

// Mirrors the redwood_ranges.kml project asset: a legend image pinned to the
// bottom-right of the screen alongside regular geometry
const SCREEN_OVERLAY_KML = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay id="legend">
      <name>Legend</name>
      <Icon>
        <href>http://www.inaturalist.org/attachments/project_assets/4-legend.png</href>
      </Icon>
      <overlayXY x="1" y="0" xunits="fraction" yunits="fraction"/>
      <screenXY x="0.99" y="0.05" xunits="fraction" yunits="fraction"/>
    </ScreenOverlay>
    <Placemark>
      <name>Giant Sequoia</name>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>-118.7,36.0,0 -118.7,36.1,0 -118.6,36.1,0 -118.7,36.0,0</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
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

  describe( "Placemarks with duplicate KML ids across sibling Folders", ( ) => {
    it( "keeps every Placemark from every Folder", ( ) => {
      const geojson = kmlAssets.kmlTextToGeoJSON( DUPLICATE_ID_KML );
      expect( geojson.features.length ).toEqual( 4 );
      const names = geojson.features.map( f => f.properties.name ).sort( );
      expect( names ).toEqual(
        ["Bay View Trail", "Marsh Trail", "Ridge Trail", "Tidelands Trail"]
      );
    } );

    it( "assigns a unique feature id to every feature", ( ) => {
      // google.maps.Data.addGeoJson keys features by id, so features sharing
      // an id silently replace each other and only one would render
      const geojson = kmlAssets.kmlTextToGeoJSON( DUPLICATE_ID_KML );
      const ids = geojson.features.map( f => f.id );
      expect( ids.every( id => id ) ).toEqual( true );
      expect( new Set( ids ).size ).toEqual( geojson.features.length );
    } );

    it( "preserves the original KML id in properties.kml_id", ( ) => {
      const geojson = kmlAssets.kmlTextToGeoJSON( DUPLICATE_ID_KML );
      const kmlIds = geojson.features.map( f => f.properties.kml_id ).sort( );
      expect( kmlIds ).toEqual( ["ID_00000", "ID_00000", "ID_00001", "ID_00001"] );
    } );

    it( "does not add kml_id to features that had no KML id", ( ) => {
      const geojson = kmlAssets.kmlTextToGeoJSON( SIMPLE_KML );
      const feature = geojson.features[0];
      expect( feature.id ).toBeTruthy( );
      expect( feature.properties ).not.toHaveProperty( "kml_id" );
    } );
  } );

  it( "skips Placemarks with no geometry", ( ) => {
    // google.maps.Data.addGeoJson throws on features with null geometry
    const kml = `<?xml version="1.0" encoding="UTF-8"?>
      <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
          <Placemark id="ID_EMPTY"><name>No geometry</name></Placemark>
          <Placemark id="ID_REAL">
            <name>Real</name>
            <Point><coordinates>1,2,0</coordinates></Point>
          </Placemark>
        </Document>
      </kml>`;
    const geojson = kmlAssets.kmlTextToGeoJSON( kml );
    expect( geojson.features.length ).toEqual( 1 );
    expect( geojson.features[0].properties.name ).toEqual( "Real" );
  } );

  describe( "ScreenOverlays", ( ) => {
    it( "extracts ScreenOverlays that togeojson ignores", ( ) => {
      const geojson = kmlAssets.kmlTextToGeoJSON( SCREEN_OVERLAY_KML );
      expect( geojson.features.length ).toEqual( 1 );
      expect( geojson.screenOverlays.length ).toEqual( 1 );
      const overlay = geojson.screenOverlays[0];
      expect( overlay.name ).toEqual( "Legend" );
      expect( overlay.iconHref )
        .toEqual( "http://www.inaturalist.org/attachments/project_assets/4-legend.png" );
      expect( overlay.position ).toEqual( "RIGHT_BOTTOM" );
    } );

    it( "skips ScreenOverlays with visibility 0", ( ) => {
      const kml = SCREEN_OVERLAY_KML.replace(
        "<name>Legend</name>",
        "<name>Legend</name><visibility>0</visibility>"
      );
      expect( kmlAssets.kmlTextToGeoJSON( kml ).screenOverlays ).toEqual( [] );
    } );

    it( "skips ScreenOverlays with no icon href", ( ) => {
      const kml = SCREEN_OVERLAY_KML.replace( /<Icon>[\s\S]*?<\/Icon>/, "" );
      expect( kmlAssets.kmlTextToGeoJSON( kml ).screenOverlays ).toEqual( [] );
    } );

    it( "captures pixel sizes", ( ) => {
      const kml = SCREEN_OVERLAY_KML.replace(
        "</ScreenOverlay>",
        "<size x=\"120\" y=\"80\" xunits=\"pixels\" yunits=\"pixels\"/></ScreenOverlay>"
      );
      const overlay = kmlAssets.kmlTextToGeoJSON( kml ).screenOverlays[0];
      expect( overlay.width ).toEqual( 120 );
      expect( overlay.height ).toEqual( 80 );
    } );
  } );
} );

describe( "screenOverlayControlPosition", ( ) => {
  const position = ( x, y, xunits, yunits ) => kmlAssets.screenOverlayControlPosition( {
    x, y, xunits: xunits || "fraction", yunits: yunits || "fraction"
  } );

  it( "maps fractions per the migration guide examples", ( ) => {
    // KML screen coordinates originate at the bottom left
    expect( position( 0, 1 ) ).toEqual( "TOP_LEFT" );
    expect( position( 1, 1 ) ).toEqual( "TOP_RIGHT" );
    expect( position( 0.99, 0.05 ) ).toEqual( "RIGHT_BOTTOM" );
    expect( position( 0, 0 ) ).toEqual( "BOTTOM_LEFT" );
    expect( position( 0.5, 1 ) ).toEqual( "TOP_CENTER" );
    expect( position( 0.5, 0.5 ) ).toEqual( "BOTTOM_CENTER" );
  } );

  it( "treats pixels as offsets from the left/bottom edges", ( ) => {
    expect( position( 10, 30, "pixels", "pixels" ) ).toEqual( "BOTTOM_LEFT" );
  } );

  it( "treats insetPixels as offsets from the right/top edges", ( ) => {
    expect( position( 10, 10, "insetPixels", "insetPixels" ) ).toEqual( "TOP_RIGHT" );
  } );

  it( "defaults to RIGHT_BOTTOM when screenXY is missing", ( ) => {
    expect( kmlAssets.screenOverlayControlPosition( null ) ).toEqual( "RIGHT_BOTTOM" );
  } );
} );

describe( "resolveScreenOverlayIcons", ( ) => {
  it( "passes through absolute http(s) hrefs", async ( ) => {
    const resolved = await kmlAssets.resolveScreenOverlayIcons( [{ iconHref: "https://example.com/legend.png" }], "/assets/a.kml", null );
    expect( resolved[0].iconUrl ).toEqual( "https://example.com/legend.png" );
  } );

  it( "resolves relative hrefs against the KML URL", async ( ) => {
    const resolved = await kmlAssets.resolveScreenOverlayIcons( [{ iconHref: "legend.png" }], "/attachments/project_assets/5-a.kml?123", null );
    expect( resolved[0].iconUrl ).toMatch( /\/attachments\/project_assets\/legend\.png$/ );
  } );

  it( "drops non-http(s) hrefs", async ( ) => {
    // eslint-disable-next-line no-script-url
    const overlays = [{ iconHref: "javascript:alert(1)" }];
    const resolved = await kmlAssets.resolveScreenOverlayIcons( overlays, "/assets/a.kml", null );
    expect( resolved ).toEqual( [] );
  } );

  it( "serves KMZ archive-relative hrefs as blob URLs", async ( ) => {
    global.URL.createObjectURL = jest.fn( ( ) => "blob:mock-legend" );
    const zip = new JSZip( );
    zip.file( "files/legend.png", "png bytes" );
    const resolved = await kmlAssets.resolveScreenOverlayIcons( [{ iconHref: "files/legend.png" }], "/assets/a.kmz", zip );
    expect( resolved[0].iconUrl ).toEqual( "blob:mock-legend" );
    expect( global.URL.createObjectURL ).toHaveBeenCalled( );
    delete global.URL.createObjectURL;
  } );
} );

describe( "kmzToKml", ( ) => {
  it( "extracts doc.kml and the archive from a KMZ", async ( ) => {
    const zip = new JSZip( );
    zip.file( "other.kml", "<kml></kml>" );
    zip.file( "doc.kml", SIMPLE_KML );
    const buffer = await zip.generateAsync( { type: "arraybuffer" } );
    const extracted = await kmlAssets.kmzToKml( buffer );
    expect( extracted.kmlText ).toEqual( SIMPLE_KML );
    expect( extracted.zip.file( "other.kml" ) ).toBeTruthy( );
  } );

  it( "falls back to the first KML entry when there is no doc.kml", async ( ) => {
    const zip = new JSZip( );
    zip.file( "something.kml", SIMPLE_KML );
    zip.file( "images/icon.png", "not kml" );
    const buffer = await zip.generateAsync( { type: "arraybuffer" } );
    const extracted = await kmlAssets.kmzToKml( buffer );
    expect( extracted.kmlText ).toEqual( SIMPLE_KML );
  } );

  it( "rejects when the archive contains no KML", async ( ) => {
    const zip = new JSZip( );
    zip.file( "readme.txt", "nothing here" );
    const buffer = await zip.generateAsync( { type: "arraybuffer" } );
    await expect( kmlAssets.kmzToKml( buffer ) ).rejects.toThrow( /no KML/ );
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

  it( "resolves ScreenOverlay icons from a fetched KML", async ( ) => {
    global.fetch = jest.fn( ).mockResolvedValue( {
      ok: true,
      text: ( ) => Promise.resolve( SCREEN_OVERLAY_KML )
    } );
    const geojson = await kmlAssets.fetchGeoJSON( "/attachments/project_assets/5-a.kml" );
    expect( geojson.screenOverlays.length ).toEqual( 1 );
    expect( geojson.screenOverlays[0].iconUrl )
      .toEqual( "http://www.inaturalist.org/attachments/project_assets/4-legend.png" );
    expect( geojson.screenOverlays[0].position ).toEqual( "RIGHT_BOTTOM" );
  } );

  it( "resolves ScreenOverlay icons packed inside a KMZ", async ( ) => {
    global.URL.createObjectURL = jest.fn( ( ) => "blob:kmz-legend" );
    const kmzKml = SCREEN_OVERLAY_KML.replace(
      "http://www.inaturalist.org/attachments/project_assets/4-legend.png",
      "files/legend.png"
    );
    const zip = new JSZip( );
    zip.file( "doc.kml", kmzKml );
    zip.file( "files/legend.png", "png bytes" );
    const buffer = await zip.generateAsync( { type: "arraybuffer" } );
    global.fetch = jest.fn( ).mockResolvedValue( {
      ok: true,
      arrayBuffer: ( ) => Promise.resolve( buffer )
    } );
    const geojson = await kmlAssets.fetchGeoJSON( "/attachments/project_assets/5-a.kmz" );
    expect( geojson.screenOverlays[0].iconUrl ).toEqual( "blob:kmz-legend" );
    delete global.URL.createObjectURL;
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

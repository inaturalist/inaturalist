import {
  parseGpx,
  flattenTrackPoints,
  computeBounds,
  matchTimestampToTrack,
  matchAllObsCards
} from "./gpx_utils";

jest.mock( "./util", () => ( {
  parsableDatetimeFormat: () => "YYYY/MM/DD h:mm A"
} ) );

const SIMPLE_GPX = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Morning Hike</name>
    <trkseg>
      <trkpt lat="45.0" lon="-122.0">
        <time>2024-06-01T10:00:00Z</time>
      </trkpt>
      <trkpt lat="45.1" lon="-122.1">
        <time>2024-06-01T11:00:00Z</time>
      </trkpt>
      <trkpt lat="45.2" lon="-122.2">
        <time>2024-06-01T12:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>`;

const MULTI_TRACK_GPX = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Track 1</name>
    <trkseg>
      <trkpt lat="10.0" lon="20.0">
        <time>2024-06-01T08:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
  <trk>
    <name>Track 2</name>
    <trkseg>
      <trkpt lat="30.0" lon="40.0">
        <time>2024-06-01T09:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>`;

const NO_TIME_GPX = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <trkseg>
      <trkpt lat="45.0" lon="-122.0"></trkpt>
      <trkpt lat="45.1" lon="-122.1"></trkpt>
    </trkseg>
  </trk>
</gpx>`;

describe( "parseGpx", () => {
  it( "parses trackpoints with lat, lng, and time", () => {
    const result = parseGpx( SIMPLE_GPX );
    expect( result.tracks ).toHaveLength( 1 );
    expect( result.tracks[0].name ).toBe( "Morning Hike" );
    expect( result.tracks[0].points ).toHaveLength( 3 );
    expect( result.tracks[0].points[0] ).toEqual( {
      lat: 45.0,
      lng: -122.0,
      time: new Date( "2024-06-01T10:00:00Z" )
    } );
  } );

  it( "parses multiple tracks", () => {
    const result = parseGpx( MULTI_TRACK_GPX );
    expect( result.tracks ).toHaveLength( 2 );
    expect( result.tracks[0].name ).toBe( "Track 1" );
    expect( result.tracks[1].name ).toBe( "Track 2" );
  } );

  it( "handles trackpoints without time", () => {
    const result = parseGpx( NO_TIME_GPX );
    expect( result.tracks[0].points ).toHaveLength( 2 );
    expect( result.tracks[0].points[0].time ).toBeNull();
  } );

  it( "skips invalid coordinates", () => {
    const gpx = `<?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1"><trk><trkseg>
      <trkpt lat="91.0" lon="0.0"><time>2024-06-01T10:00:00Z</time></trkpt>
      <trkpt lat="45.0" lon="181.0"><time>2024-06-01T10:00:00Z</time></trkpt>
      <trkpt lat="45.0" lon="-122.0"><time>2024-06-01T10:00:00Z</time></trkpt>
    </trkseg></trk></gpx>`;
    const result = parseGpx( gpx );
    expect( result.tracks[0].points ).toHaveLength( 1 );
    expect( result.tracks[0].points[0].lat ).toBe( 45.0 );
  } );

  it( "throws on invalid XML", () => {
    expect( () => parseGpx( "not xml at all <<<<" ) ).toThrow( "Invalid GPX file" );
  } );

  it( "returns empty tracks for GPX with no tracks", () => {
    const gpx = `<?xml version="1.0" encoding="UTF-8"?><gpx version="1.1"></gpx>`;
    const result = parseGpx( gpx );
    expect( result.tracks ).toHaveLength( 0 );
  } );
} );

describe( "flattenTrackPoints", () => {
  it( "merges tracks and sorts by time", () => {
    const parsed = parseGpx( MULTI_TRACK_GPX );
    const flat = flattenTrackPoints( parsed );
    expect( flat ).toHaveLength( 2 );
    expect( flat[0].lat ).toBe( 10.0 );
    expect( flat[1].lat ).toBe( 30.0 );
  } );

  it( "filters out points without timestamps", () => {
    const parsed = parseGpx( NO_TIME_GPX );
    const flat = flattenTrackPoints( parsed );
    expect( flat ).toHaveLength( 0 );
  } );

  it( "sorts unsorted points by time", () => {
    const parsed = {
      tracks: [{
        name: "",
        points: [
          { lat: 2, lng: 2, time: new Date( "2024-06-01T12:00:00Z" ) },
          { lat: 1, lng: 1, time: new Date( "2024-06-01T10:00:00Z" ) }
        ]
      }]
    };
    const flat = flattenTrackPoints( parsed );
    expect( flat[0].lat ).toBe( 1 );
    expect( flat[1].lat ).toBe( 2 );
  } );
} );

describe( "computeBounds", () => {
  it( "computes north/south/east/west bounds", () => {
    const points = [
      { lat: 45.0, lng: -122.0 },
      { lat: 45.2, lng: -121.8 },
      { lat: 44.8, lng: -122.2 }
    ];
    const bounds = computeBounds( points );
    expect( bounds ).toEqual( {
      north: 45.2,
      south: 44.8,
      east: -121.8,
      west: -122.2
    } );
  } );

  it( "returns null for empty points", () => {
    expect( computeBounds( [] ) ).toBeNull();
  } );

  it( "handles single point", () => {
    const bounds = computeBounds( [{ lat: 45.0, lng: -122.0 }] );
    expect( bounds.north ).toBe( 45.0 );
    expect( bounds.south ).toBe( 45.0 );
  } );
} );

describe( "matchTimestampToTrack", () => {
  const points = [
    { lat: 45.0, lng: -122.0, time: new Date( "2024-06-01T10:00:00Z" ) },
    { lat: 45.1, lng: -122.1, time: new Date( "2024-06-01T11:00:00Z" ) },
    { lat: 45.2, lng: -122.2, time: new Date( "2024-06-01T12:00:00Z" ) }
  ];

  it( "returns null for empty points", () => {
    expect( matchTimestampToTrack( Date.now(), [] ) ).toBeNull();
  } );

  it( "returns null for null timestamp", () => {
    expect( matchTimestampToTrack( null, points ) ).toBeNull();
  } );

  it( "matches exact timestamp", () => {
    const ts = new Date( "2024-06-01T10:00:00Z" ).getTime();
    const match = matchTimestampToTrack( ts, points );
    expect( match.lat ).toBe( 45.0 );
    expect( match.lng ).toBe( -122.0 );
  } );

  it( "interpolates between trackpoints (linear fallback)", () => {
    // Halfway between first and second point
    const ts = new Date( "2024-06-01T10:30:00Z" ).getTime();
    const match = matchTimestampToTrack( ts, points );
    expect( match.lat ).toBeCloseTo( 45.05, 2 );
    expect( match.lng ).toBeCloseTo( -122.05, 2 );
  } );

  it( "matches before first point within threshold", () => {
    // 10 minutes before first point
    const ts = new Date( "2024-06-01T09:50:00Z" ).getTime();
    const match = matchTimestampToTrack( ts, points );
    expect( match ).not.toBeNull();
    expect( match.lat ).toBe( 45.0 );
  } );

  it( "returns null for timestamp far before track", () => {
    // 2 hours before
    const ts = new Date( "2024-06-01T08:00:00Z" ).getTime();
    expect( matchTimestampToTrack( ts, points ) ).toBeNull();
  } );

  it( "matches after last point within threshold", () => {
    // 10 minutes after last point
    const ts = new Date( "2024-06-01T12:10:00Z" ).getTime();
    const match = matchTimestampToTrack( ts, points );
    expect( match ).not.toBeNull();
    expect( match.lat ).toBe( 45.2 );
  } );

  it( "returns null for timestamp far after track", () => {
    const ts = new Date( "2024-06-01T14:00:00Z" ).getTime();
    expect( matchTimestampToTrack( ts, points ) ).toBeNull();
  } );

  it( "handles single trackpoint within threshold", () => {
    const singlePoint = [
      { lat: 45.0, lng: -122.0, time: new Date( "2024-06-01T10:00:00Z" ) }
    ];
    const ts = new Date( "2024-06-01T10:05:00Z" ).getTime();
    const match = matchTimestampToTrack( ts, singlePoint );
    expect( match ).not.toBeNull();
    expect( match.lat ).toBe( 45.0 );
  } );

  it( "returns null for single trackpoint beyond threshold", () => {
    const singlePoint = [
      { lat: 45.0, lng: -122.0, time: new Date( "2024-06-01T10:00:00Z" ) }
    ];
    const ts = new Date( "2024-06-01T12:00:00Z" ).getTime();
    expect( matchTimestampToTrack( ts, singlePoint ) ).toBeNull();
  } );
} );

describe( "matchAllObsCards", () => {
  const sortedPoints = [
    { lat: 45.0, lng: -122.0, time: new Date( "2024-06-01T10:00:00Z" ) },
    { lat: 45.2, lng: -122.2, time: new Date( "2024-06-01T12:00:00Z" ) }
  ];

  it( "matches cards with file metadata dates", () => {
    const obsCards = {
      1: { id: 1 },
      2: { id: 2 }
    };
    const files = {
      10: { cardID: 1, metadata: { date: "2024/06/01 10:00 AM" } },
      20: { cardID: 2, metadata: { date: "2024/06/01 12:00 PM" } }
    };
    const results = matchAllObsCards( obsCards, files, sortedPoints );
    expect( Object.keys( results ) ).toHaveLength( 2 );
    expect( results[1].lat ).toBeCloseTo( 45.0, 1 );
    expect( results[2].lat ).toBeCloseTo( 45.2, 1 );
  } );

  it( "skips cards without dates", () => {
    const obsCards = {
      1: { id: 1 },
      2: { id: 2 }
    };
    const files = {
      10: { cardID: 1, metadata: { date: "2024/06/01 10:00 AM" } },
      20: { cardID: 2, metadata: {} }
    };
    const results = matchAllObsCards( obsCards, files, sortedPoints );
    expect( Object.keys( results ) ).toHaveLength( 1 );
    expect( results[1] ).toBeDefined();
    expect( results[2] ).toBeUndefined();
  } );

  it( "falls back to card.date when file has no metadata", () => {
    const obsCards = {
      1: { id: 1, date: "2024/06/01 11:00 AM" }
    };
    const files = {};
    const results = matchAllObsCards( obsCards, files, sortedPoints );
    expect( Object.keys( results ) ).toHaveLength( 1 );
    expect( results[1].lat ).toBeCloseTo( 45.1, 1 );
  } );

  it( "returns empty for no obs cards", () => {
    const results = matchAllObsCards( {}, {}, sortedPoints );
    expect( Object.keys( results ) ).toHaveLength( 0 );
  } );
} );

/**
 * @jest-environment node
 */
import { DOMParser } from "@xmldom/xmldom";
import { FitBaseType, FitEncoder } from "fit-file-parser";
import {
  fromFit,
  fromGpx,
  fromStravaStreams,
  fromTcx,
  parseTrack,
  trackFormatFromFileName
} from "./index";

// Errors still throw; this just keeps xmldom from logging them
const parseXml = xml => new DOMParser( { onError: ( ) => {} } ).parseFromString( xml, "application/xml" );
const t = iso => Date.parse( iso );

const MULTI_SEGMENT_GPX = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>Morning Hike</name>
    <trkseg>
      <trkpt lat="45.1" lon="-122.1"><ele>12.5</ele><time>2024-06-01T11:00:00Z</time></trkpt>
      <trkpt lat="45.0" lon="-122.0"><time>2024-06-01T10:00:00Z</time></trkpt>
      <trkpt lat="45.05" lon="-122.05"></trkpt>
    </trkseg>
    <trkseg>
      <trkpt lat="46.0" lon="-123.0"><time>2024-06-01T13:00:00Z</time></trkpt>
      <trkpt lat="91.0" lon="0.0"><time>2024-06-01T13:30:00Z</time></trkpt>
    </trkseg>
  </trk>
  <trk>
    <trkseg>
      <trkpt lat="47.0" lon="-124.0"><time>2024-06-01T14:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>`;

const TCX = `<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
  <Activities>
    <Activity Sport="Running">
      <Id>2024-06-01T10:00:00Z</Id>
      <Lap StartTime="2024-06-01T10:00:00Z">
        <Track>
          <Trackpoint>
            <Time>2024-06-01T10:00:00Z</Time>
            <Position><LatitudeDegrees>45</LatitudeDegrees><LongitudeDegrees>-122</LongitudeDegrees></Position>
            <AltitudeMeters>100</AltitudeMeters>
          </Trackpoint>
          <Trackpoint><Time>2024-06-01T10:05:00Z</Time></Trackpoint>
          <Trackpoint>
            <Time>2024-06-01T10:10:00Z</Time>
            <Position><LatitudeDegrees>45.1</LatitudeDegrees><LongitudeDegrees>-122.1</LongitudeDegrees></Position>
          </Trackpoint>
        </Track>
      </Lap>
    </Activity>
  </Activities>
</TrainingCenterDatabase>`;

const SEMICIRCLES_PER_DEGREE = 2 ** 31 / 180;

function fitFile( records ) {
  // Real devices write protocol 2.0 as 0x20 (major version in the high
  // nibble); the encoder's default of 2 fails the reader's header check
  const encoder = new FitEncoder( { protocolVersion: 0x20 } );
  // file_id with type = activity
  encoder.writeMessage( 0, [{
    number: 0,
    size: 1,
    baseType: FitBaseType.Enum,
    value: 4
  }] );
  const sint32 = ( number, value ) => ( {
    number,
    size: 4,
    baseType: FitBaseType.Sint32,
    value
  } );
  records.forEach( ( { iso, lat, lng } ) => {
    const fields = [{
      number: 253,
      size: 4,
      baseType: FitBaseType.Uint32,
      value: FitEncoder.toFitTimestamp( new Date( iso ) )
    }];
    if ( lat !== undefined ) {
      fields.push(
        sint32( 0, Math.round( lat * SEMICIRCLES_PER_DEGREE ) ),
        sint32( 1, Math.round( lng * SEMICIRCLES_PER_DEGREE ) )
      );
    }
    // Records with and without position need different local definitions
    encoder.writeMessage( 20, fields, lat === undefined ? 1 : 0 );
  } );
  const bytes = encoder.close( );
  return bytes.buffer.slice( bytes.byteOffset, bytes.byteOffset + bytes.byteLength );
}

describe( "fromGpx", ( ) => {
  it( "merges all tracks and segments into one sorted track", ( ) => {
    const track = fromGpx( MULTI_SEGMENT_GPX, { parseXml } );
    expect( track.source ).toBe( "gpx" );
    expect( track.name ).toBe( "Morning Hike" );
    expect( track.points ).toEqual( [
      { lat: 45.0, lng: -122.0, timeMs: t( "2024-06-01T10:00:00Z" ) },
      {
        lat: 45.1, lng: -122.1, timeMs: t( "2024-06-01T11:00:00Z" ), ele: 12.5
      },
      { lat: 46.0, lng: -123.0, timeMs: t( "2024-06-01T13:00:00Z" ) },
      { lat: 47.0, lng: -124.0, timeMs: t( "2024-06-01T14:00:00Z" ) }
    ] );
  } );

  it( "handles namespace-prefixed elements", ( ) => {
    const prefixed = `<g:gpx xmlns:g="http://www.topografix.com/GPX/1/1"><g:trk><g:trkseg>
      <g:trkpt lat="1" lon="2"><g:time>2024-06-01T10:00:00Z</g:time></g:trkpt>
    </g:trkseg></g:trk></g:gpx>`;
    expect( fromGpx( prefixed, { parseXml } ).points ).toHaveLength( 1 );
  } );

  it( "throws on invalid XML and on non-GPX documents", ( ) => {
    expect( ( ) => fromGpx( "not xml <<<<", { parseXml } ) ).toThrow( "Invalid XML" );
    expect( ( ) => fromGpx( TCX, { parseXml } ) ).toThrow( "Not a GPX document" );
  } );

  it( "throws when there is no DOMParser and none is passed", ( ) => {
    expect( ( ) => fromGpx( MULTI_SEGMENT_GPX ) ).toThrow( "Invalid XML" );
  } );
} );

describe( "fromTcx", ( ) => {
  it( "reads trackpoints with positions", ( ) => {
    const track = fromTcx( TCX, { parseXml } );
    expect( track.source ).toBe( "tcx" );
    expect( track.name ).toBe( "Running" );
    expect( track.points ).toEqual( [
      {
        lat: 45, lng: -122, timeMs: t( "2024-06-01T10:00:00Z" ), ele: 100
      },
      { lat: 45.1, lng: -122.1, timeMs: t( "2024-06-01T10:10:00Z" ) }
    ] );
  } );
} );

describe( "fromFit", ( ) => {
  it( "reads record positions and timestamps", async ( ) => {
    const track = await fromFit( fitFile( [
      { iso: "2024-06-01T10:01:00Z", lat: 45.1, lng: -122.1 },
      { iso: "2024-06-01T10:00:00Z", lat: 45.0, lng: -122.0 },
      { iso: "2024-06-01T10:02:00Z" }
    ] ) );
    expect( track.source ).toBe( "fit" );
    expect( track.points ).toHaveLength( 2 );
    expect( track.points[0].timeMs ).toBe( t( "2024-06-01T10:00:00Z" ) );
    expect( track.points[0].lat ).toBeCloseTo( 45.0, 6 );
    expect( track.points[1].lng ).toBeCloseTo( -122.1, 6 );
  } );

  it( "rejects data that isn't a FIT file", async ( ) => {
    await expect( fromFit( new TextEncoder( ).encode( "nope" ).buffer ) ).rejects.toThrow( "Invalid FIT file" );
  } );
} );

describe( "fromStravaStreams", ( ) => {
  it( "offsets the time stream from the activity start", ( ) => {
    const track = fromStravaStreams( {
      latlng: { data: [[45.0, -122.0], [45.1, -122.1]] },
      time: { data: [0, 90] }
    }, "2024-06-01T10:00:00Z", "Lunch Ride" );
    expect( track ).toEqual( {
      source: "strava",
      name: "Lunch Ride",
      points: [
        { lat: 45.0, lng: -122.0, timeMs: t( "2024-06-01T10:00:00Z" ) },
        { lat: 45.1, lng: -122.1, timeMs: t( "2024-06-01T10:01:30Z" ) }
      ]
    } );
  } );

  it( "returns an empty track for missing streams", ( ) => {
    expect( fromStravaStreams( {}, "2024-06-01T10:00:00Z" ).points ).toEqual( [] );
  } );
} );

describe( "trackFormatFromFileName", ( ) => {
  it( "detects formats case-insensitively", ( ) => {
    expect( trackFormatFromFileName( "Morning_Hike.GPX" ) ).toBe( "gpx" );
    expect( trackFormatFromFileName( "activity.tcx" ) ).toBe( "tcx" );
    expect( trackFormatFromFileName( "123456.fit" ) ).toBe( "fit" );
    expect( trackFormatFromFileName( "photo.jpg" ) ).toBeNull( );
  } );
} );

describe( "parseTrack", ( ) => {
  it( "dispatches by format and always returns a promise", async ( ) => {
    await expect( parseTrack( MULTI_SEGMENT_GPX, "gpx", { parseXml } ) ).resolves.toMatchObject( { source: "gpx" } );
    await expect( parseTrack( TCX, "tcx", { parseXml } ) ).resolves.toMatchObject( { source: "tcx" } );
    await expect( parseTrack( "", "kml" ) ).rejects.toThrow( "Unsupported track format" );
  } );
} );

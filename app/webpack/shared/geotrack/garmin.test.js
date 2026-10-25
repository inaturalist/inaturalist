/**
 * @jest-environment node
 */
import JSZip from "jszip";
import {
  downloadGarminActivityFile,
  exchangeGarminApiKey,
  GARMIN_PERSONAL_API_URL,
  GarminApiError,
  garminTokenExpired,
  normalizeGarminActivity,
  searchGarminActivities
} from "./index";
import { extractFirstFile } from "./zip";

function response( {
  status = 200,
  body = "",
  json,
  arrayBuffer
} = {} ) {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async ( ) => body,
    json: async ( ) => json,
    arrayBuffer: async ( ) => arrayBuffer
  };
}

async function zipOf( files, compression = "DEFLATE" ) {
  const zip = new JSZip( );
  Object.entries( files ).forEach( ( [name, content] ) => zip.file( name, content ) );
  return zip.generateAsync( { type: "arraybuffer", compression } );
}

function jwt( claims ) {
  const encode = obj => Buffer.from( JSON.stringify( obj ) ).toString( "base64url" );
  return `${encode( { alg: "RS256" } )}.${encode( claims )}.signature`;
}

const GPX = "<gpx><trk><trkseg><trkpt lat=\"1\" lon=\"2\"><time>2024-06-01T17:00:00Z</time></trkpt></trkseg></trk></gpx>";

describe( "extractFirstFile", ( ) => {
  it( "inflates a deflated entry", async ( ) => {
    const file = await extractFirstFile( await zipOf( { "1_ACTIVITY.gpx": GPX } ) );
    expect( file.name ).toBe( "1_ACTIVITY.gpx" );
    expect( new TextDecoder( ).decode( file.bytes ) ).toBe( GPX );
  } );

  it( "reads a stored entry and skips directories", async ( ) => {
    const zip = new JSZip( );
    zip.folder( "dir" );
    zip.file( "dir/a.fit", new Uint8Array( [1, 2, 3] ) );
    const buffer = await zip.generateAsync( { type: "arraybuffer", compression: "STORE" } );
    const file = await extractFirstFile( buffer );
    expect( file.name ).toBe( "dir/a.fit" );
    expect( Array.from( file.bytes ) ).toEqual( [1, 2, 3] );
  } );

  it( "uses an injected inflateRaw", async ( ) => {
    const inflateRaw = jest.fn( async ( ) => new Uint8Array( [9] ) );
    const file = await extractFirstFile( await zipOf( { "a.fit": "x".repeat( 100 ) } ), { inflateRaw } );
    expect( inflateRaw ).toHaveBeenCalled( );
    expect( Array.from( file.bytes ) ).toEqual( [9] );
  } );

  it( "rejects entries over maxBytes, even when the header understates them", async ( ) => {
    const buffer = await zipOf( { "a.fit": "x".repeat( 1000 ) } );
    await expect( extractFirstFile( buffer, { maxBytes: 100 } ) ).rejects.toThrow( "too large" );
    // Lie about the size in the central directory to exercise the inflate limit
    const view = new DataView( buffer );
    const end = new Uint8Array( buffer ).length - 22;
    const central = view.getUint32( end + 16, true );
    view.setUint32( central + 24, 10, true );
    await expect( extractFirstFile( buffer, { maxBytes: 100 } ) ).rejects.toThrow( "too large" );
  } );

  it( "rejects non-zip data", async ( ) => {
    await expect( extractFirstFile( new ArrayBuffer( 40 ) ) ).rejects.toThrow( "Not a zip archive" );
  } );
} );

describe( "exchangeGarminApiKey", ( ) => {
  it( "posts the key and reads the expiry from the JWT", async ( ) => {
    const token = jwt( { exp: 1800000000 } );
    const fetch = jest.fn( async ( ) => response( { body: `"${token}"\n` } ) );
    const result = await exchangeGarminApiKey( "  my-key ", { fetch } );
    expect( result ).toEqual( { accessToken: token, expiresAtMs: 1800000000000 } );
    const [url, init] = fetch.mock.calls[0];
    expect( url ).toBe( `${GARMIN_PERSONAL_API_URL}/personalapitoken-service/personal-api/personal-api-key/token` );
    expect( init.method ).toBe( "POST" );
    expect( init.headers.Authorization ).toBe( "ApiKey my-key" );
  } );

  it( "falls back to a 24 hour lifetime for opaque tokens", async ( ) => {
    const fetch = async ( ) => response( { body: "opaque" } );
    const result = await exchangeGarminApiKey( "k", { fetch, nowMs: 1000 } );
    expect( result.expiresAtMs ).toBe( 1000 + 24 * 60 * 60 * 1000 );
  } );

  it( "sends requests to a relay base URL", async ( ) => {
    const fetch = jest.fn( async ( ) => response( { body: "t" } ) );
    await exchangeGarminApiKey( "k", { fetch, baseUrl: "/garmin_relay/" } );
    expect( fetch.mock.calls[0][0] ).toBe( "/garmin_relay/personalapitoken-service/personal-api/personal-api-key/token" );
  } );

  it( "flags a rejected key as unauthorized", async ( ) => {
    const fetch = async ( ) => response( { status: 401 } );
    const error = await exchangeGarminApiKey( "bad", { fetch } ).catch( e => e );
    expect( error ).toBeInstanceOf( GarminApiError );
    expect( error.unauthorized ).toBe( true );
  } );

  it( "wraps network failures, such as a blocked CORS request", async ( ) => {
    const fetch = async ( ) => { throw new TypeError( "Failed to fetch" ); };
    const error = await exchangeGarminApiKey( "k", { fetch } ).catch( e => e );
    expect( error ).toBeInstanceOf( GarminApiError );
    expect( error.status ).toBeNull( );
  } );

  it( "rejects a blank key without a request", async ( ) => {
    const fetch = jest.fn( );
    await expect( exchangeGarminApiKey( " ", { fetch } ) ).rejects.toThrow( "Missing" );
    expect( fetch ).not.toHaveBeenCalled( );
  } );
} );

describe( "garminTokenExpired", ( ) => {
  it( "treats tokens within five minutes of expiry as expired", ( ) => {
    expect( garminTokenExpired( null ) ).toBe( true );
    expect( garminTokenExpired( { accessToken: "t", expiresAtMs: 10 * 60 * 1000 }, 0 ) ).toBe( false );
    expect( garminTokenExpired( { accessToken: "t", expiresAtMs: 4 * 60 * 1000 }, 0 ) ).toBe( true );
  } );
} );

describe( "searchGarminActivities", ( ) => {
  const raw = {
    activityId: 123,
    activityName: "Morning Walk",
    activityType: { typeKey: "walking" },
    startTimeGMT: "2024-06-01 17:00:00",
    duration: 1700.5,
    elapsedDuration: 1800,
    distance: 2500.2,
    hasPolyline: true
  };

  it( "normalizes activities and sends the bearer token", async ( ) => {
    const fetch = jest.fn( async ( ) => response( { json: [raw] } ) );
    const activities = await searchGarminActivities( { accessToken: "tok" }, {
      fetch,
      limit: 100,
      startDate: "2024-06-01",
      endDate: "2024-06-02"
    } );
    expect( activities ).toEqual( [{
      id: 123,
      name: "Morning Walk",
      type: "walking",
      startTimeMs: Date.UTC( 2024, 5, 1, 17 ),
      durationMs: 1800000,
      distanceM: 2500.2,
      hasTrack: true
    }] );
    const [url, init] = fetch.mock.calls[0];
    const params = new URL( url ).searchParams;
    expect( params.get( "limit" ) ).toBe( "45" );
    expect( params.get( "startDate" ) ).toBe( "2024-06-01" );
    expect( init.headers.Authorization ).toBe( "Bearer tok" );
  } );

  it( "marks activities without a start position as trackless", ( ) => {
    expect( normalizeGarminActivity( { activityId: 1 } ).hasTrack ).toBe( false );
    expect( normalizeGarminActivity( { activityId: 1, startLatitude: 1 } ).hasTrack ).toBe( true );
  } );
} );

describe( "downloadGarminActivityFile", ( ) => {
  it( "unzips a FIT download to an ArrayBuffer", async ( ) => {
    const fit = new Uint8Array( [14, 32, 1, 2] );
    const fetch = jest.fn( async ( ) => response( { arrayBuffer: await zipOf( { "123_ACTIVITY.fit": fit } ) } ) );
    const file = await downloadGarminActivityFile( "tok", 123, { fetch } );
    expect( file.fileName ).toBe( "123_ACTIVITY.fit" );
    expect( file.format ).toBe( "fit" );
    expect( file.content ).toBeInstanceOf( ArrayBuffer );
    expect( Array.from( new Uint8Array( file.content ) ) ).toEqual( Array.from( fit ) );
    const [url, init] = fetch.mock.calls[0];
    expect( url ).toBe( `${GARMIN_PERSONAL_API_URL}/download-service/files/activity/123` );
    expect( init.headers.Accept ).toBe( "application/x-zip-compressed" );
  } );

  it( "decodes XML downloads to text", async ( ) => {
    const fetch = async ( ) => response( { arrayBuffer: await zipOf( { "123.gpx": GPX } ) } );
    const file = await downloadGarminActivityFile( "tok", 123, { fetch } );
    expect( file ).toEqual( { fileName: "123.gpx", format: "gpx", content: GPX } );
  } );

  it( "rejects unsupported files and bad ids", async ( ) => {
    const fetch = async ( ) => response( { arrayBuffer: await zipOf( { "123.kml": "<kml/>" } ) } );
    await expect( downloadGarminActivityFile( "tok", 123, { fetch } ) ).rejects.toThrow( "Unsupported" );
    await expect( downloadGarminActivityFile( "tok", "../1", { fetch } ) ).rejects.toThrow( "Invalid" );
  } );
} );

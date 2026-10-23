/**
 * @jest-environment node
 */
import {
  parseUtcOffset,
  parseWallClock,
  photoTimeMs
} from "./time";

const t = iso => Date.parse( iso );

describe( "parseWallClock", ( ) => {
  it( "parses EXIF and ISO-ish formats as if UTC", ( ) => {
    expect( parseWallClock( "2024:06:01 10:00:30" ) ).toBe( t( "2024-06-01T10:00:30Z" ) );
    expect( parseWallClock( "2024-06-01 10:00" ) ).toBe( t( "2024-06-01T10:00:00Z" ) );
    expect( parseWallClock( "2024-06-01T10:00:00" ) ).toBe( t( "2024-06-01T10:00:00Z" ) );
  } );

  it( "returns null for unparseable input", ( ) => {
    expect( parseWallClock( "June 1st" ) ).toBeNull( );
    expect( parseWallClock( null ) ).toBeNull( );
  } );
} );

describe( "parseUtcOffset", ( ) => {
  it( "parses offsets into minutes east of UTC", ( ) => {
    expect( parseUtcOffset( "+09:00" ) ).toBe( 540 );
    expect( parseUtcOffset( "-0730" ) ).toBe( -450 );
    expect( parseUtcOffset( "Z" ) ).toBe( 0 );
    expect( parseUtcOffset( "PST" ) ).toBeNull( );
  } );
} );

describe( "photoTimeMs", ( ) => {
  it( "prefers the EXIF offset", ( ) => {
    expect( photoTimeMs( {
      dateTime: "2024:06:01 10:00:00",
      offset: "-07:00",
      gpsDateTime: "2024:06:01 00:00:00",
      timeZone: "Asia/Tokyo"
    } ) ).toEqual( { timeMs: t( "2024-06-01T17:00:00Z" ), basis: "offset" } );
  } );

  it( "uses the GPS UTC stamp when there is no offset", ( ) => {
    expect( photoTimeMs( {
      dateTime: "2024:06:01 10:00:00",
      gpsDateTime: "2024:06:01 17:00:05",
      timeZone: "Asia/Tokyo"
    } ) ).toEqual( { timeMs: t( "2024-06-01T17:00:05Z" ), basis: "gps" } );
  } );

  it( "falls back to the supplied time zone", ( ) => {
    expect( photoTimeMs( {
      dateTime: "2024:06:01 10:00:00",
      timeZone: "America/Los_Angeles"
    } ) ).toEqual( { timeMs: t( "2024-06-01T17:00:00Z" ), basis: "zone" } );
    expect( photoTimeMs( {
      dateTime: "2024:01:15 10:00:00",
      timeZone: "America/Los_Angeles"
    } ).timeMs ).toBe( t( "2024-01-15T18:00:00Z" ) );
  } );

  it( "handles wall-clock times next to a DST change", ( ) => {
    // US DST started 2024-03-10 at 02:00 local
    expect( photoTimeMs( {
      dateTime: "2024:03:10 01:30:00",
      timeZone: "America/Los_Angeles"
    } ).timeMs ).toBe( t( "2024-03-10T09:30:00Z" ) );
    expect( photoTimeMs( {
      dateTime: "2024:03:10 03:30:00",
      timeZone: "America/Los_Angeles"
    } ).timeMs ).toBe( t( "2024-03-10T10:30:00Z" ) );
  } );

  it( "applies a camera clock offset except to GPS stamps", ( ) => {
    const clockOffsetMs = -5 * 60 * 1000;
    expect( photoTimeMs( {
      dateTime: "2024:06:01 10:00:00",
      offset: "+00:00",
      clockOffsetMs
    } ).timeMs ).toBe( t( "2024-06-01T09:55:00Z" ) );
    expect( photoTimeMs( {
      gpsDateTime: "2024:06:01 10:00:00",
      clockOffsetMs
    } ).timeMs ).toBe( t( "2024-06-01T10:00:00Z" ) );
  } );

  it( "returns null without enough information", ( ) => {
    expect( photoTimeMs( { dateTime: "2024:06:01 10:00:00" } ) ).toBeNull( );
    expect( photoTimeMs( { dateTime: "2024:06:01 10:00:00", timeZone: "Not/AZone" } ) ).toBeNull( );
    expect( photoTimeMs( ) ).toBeNull( );
  } );
} );

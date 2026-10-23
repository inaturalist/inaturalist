/**
 * @jest-environment node
 */
import { matchMany, matchTime } from "./match";
import { computeBounds, normalizeTrack } from "./track";

const t = iso => Date.parse( iso );

const track = normalizeTrack( {
  source: "test",
  points: [
    { lat: 45.0, lng: -122.0, timeMs: t( "2024-06-01T10:00:00Z" ) },
    { lat: 45.1, lng: -122.1, timeMs: t( "2024-06-01T10:20:00Z" ) },
    { lat: 45.2, lng: -122.2, timeMs: t( "2024-06-01T10:40:00Z" ) },
    // Recording paused for two hours
    { lat: 46.0, lng: -123.0, timeMs: t( "2024-06-01T12:40:00Z" ) }
  ]
} );

describe( "normalizeTrack", ( ) => {
  it( "sorts points and drops ones without time or valid coordinates", ( ) => {
    const normalized = normalizeTrack( {
      source: "test",
      points: [
        { lat: 2, lng: 2, timeMs: 2000 },
        { lat: 1, lng: 1, timeMs: 1000 },
        { lat: 91, lng: 0, timeMs: 3000 },
        { lat: 0, lng: 181, timeMs: 3000 },
        { lat: 0, lng: 0, timeMs: NaN }
      ]
    } );
    expect( normalized.points.map( p => p.lat ) ).toEqual( [1, 2] );
  } );
} );

describe( "computeBounds", ( ) => {
  it( "computes north/south/east/west", ( ) => {
    expect( computeBounds( track.points ) ).toEqual( {
      north: 46.0,
      south: 45.0,
      east: -122.0,
      west: -123.0
    } );
  } );

  it( "returns null for no points", ( ) => {
    expect( computeBounds( [] ) ).toBeNull( );
  } );
} );

describe( "matchTime", ( ) => {
  it( "returns null for an empty track or missing time", ( ) => {
    expect( matchTime( t( "2024-06-01T10:00:00Z" ), { points: [] } ) ).toBeNull( );
    expect( matchTime( null, track ) ).toBeNull( );
  } );

  it( "matches an exact point with the minimum accuracy", ( ) => {
    expect( matchTime( t( "2024-06-01T10:20:00Z" ), track ) ).toEqual( {
      lat: 45.1,
      lng: -122.1,
      accuracyM: 10,
      method: "exact"
    } );
  } );

  it( "interpolates between points with accuracy of half the segment", ( ) => {
    const match = matchTime( t( "2024-06-01T10:10:00Z" ), track );
    expect( match.method ).toBe( "interpolated" );
    expect( match.lat ).toBeCloseTo( 45.05, 2 );
    expect( match.lng ).toBeCloseTo( -122.05, 2 );
    // The segment is ~13.6 km
    expect( match.accuracyM ).toBeGreaterThan( 6500 );
    expect( match.accuracyM ).toBeLessThan( 7000 );
  } );

  it( "clamps to the ends within maxExtrapolationMs", ( ) => {
    const before = matchTime( t( "2024-06-01T09:50:00Z" ), track );
    expect( before ).toMatchObject( { lat: 45.0, method: "clamped" } );
    const after = matchTime( t( "2024-06-01T12:50:00Z" ), track );
    expect( after ).toMatchObject( { lat: 46.0, method: "clamped" } );
  } );

  it( "returns null beyond maxExtrapolationMs", ( ) => {
    expect( matchTime( t( "2024-06-01T09:00:00Z" ), track ) ).toBeNull( );
    expect( matchTime( t( "2024-06-01T14:00:00Z" ), track ) ).toBeNull( );
  } );

  it( "does not interpolate across a recording pause", ( ) => {
    // 10 minutes into a two-hour pause: stays at the last point before it
    expect( matchTime( t( "2024-06-01T10:50:00Z" ), track ) ).toMatchObject( {
      lat: 45.2,
      method: "clamped"
    } );
    // 10 minutes before recording resumes: the first point after it
    expect( matchTime( t( "2024-06-01T12:30:00Z" ), track ) ).toMatchObject( {
      lat: 46.0,
      method: "clamped"
    } );
    // Middle of the pause is too far from either end
    expect( matchTime( t( "2024-06-01T11:40:00Z" ), track ) ).toBeNull( );
  } );

  it( "respects option overrides", ( ) => {
    const match = matchTime( t( "2024-06-01T11:40:00Z" ), track, { maxGapMs: 3 * 60 * 60 * 1000 } );
    expect( match.method ).toBe( "interpolated" );
    expect( matchTime( t( "2024-06-01T10:20:00Z" ), track, { minAccuracyM: 25 } ).accuracyM ).toBe( 25 );
  } );

  it( "interpolates across the antimeridian along the short path", ( ) => {
    const crossing = normalizeTrack( {
      points: [
        { lat: 0, lng: 179.9, timeMs: 0 },
        { lat: 0, lng: -179.9, timeMs: 1000 }
      ]
    } );
    const match = matchTime( 500, crossing );
    expect( Math.abs( match.lng ) ).toBeCloseTo( 180, 5 );
  } );
} );

describe( "matchMany", ( ) => {
  it( "returns matches keyed by id and skips unmatched items", ( ) => {
    const matches = matchMany( [
      { id: "a", timeMs: t( "2024-06-01T10:00:00Z" ) },
      { id: "b", timeMs: t( "2024-06-01T08:00:00Z" ) },
      { id: "c", timeMs: null }
    ], track );
    expect( Object.keys( matches ) ).toEqual( ["a"] );
    expect( matches.a.lat ).toBe( 45.0 );
  } );
} );

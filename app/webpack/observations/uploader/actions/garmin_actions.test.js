import * as geotrack from "../../../shared/geotrack";
import actions from "./actions";
import * as types from "../constants/constants";

// ESM-only packages jest doesn't transform, imported by the upload helpers
jest.mock( "uuid", ( ) => ( { v4: ( ) => "uuid" } ) );
jest.mock( "heic-to", ( ) => ( {} ) );

jest.mock( "../models/garmin_relay", ( ) => ( {
  garminRelayOptions: ( ) => ( { baseUrl: "/garmin_relay" } )
} ) );

jest.mock( "../../../shared/geotrack", ( ) => ( {
  ...jest.requireActual( "../../../shared/geotrack" ),
  exchangeGarminApiKey: jest.fn( ),
  searchGarminActivities: jest.fn( ),
  downloadGarminActivityFile: jest.fn( )
} ) );

const GPX = "<gpx><trk><trkseg><trkpt lat=\"1\" lon=\"2\"><time>2024-06-01T17:00:00Z</time></trkpt></trkseg></trk></gpx>";

// Runs thunks against a tiny store applying SET_STATE / UPDATE_STATE
function makeStore( garmin = {} ) {
  let state = {
    config: {},
    dragDropZone: {
      obsCards: {},
      files: {},
      gpsTrack: null,
      garmin: {
        enabled: true,
        show: true,
        token: null,
        activities: null,
        loading: false,
        importingId: null,
        error: null,
        ...garmin
      }
    }
  };
  const getState = ( ) => state;
  const dispatch = action => {
    if ( typeof action === "function" ) return action( dispatch, getState );
    if ( action.type === types.SET_STATE || action.type === types.UPDATE_STATE ) {
      const dragDropZone = { ...state.dragDropZone };
      Object.entries( action.attrs ).forEach( ( [key, value] ) => {
        dragDropZone[key] = action.type === types.UPDATE_STATE
          ? { ...dragDropZone[key], ...value }
          : value;
      } );
      state = { ...state, dragDropZone };
    }
    return action;
  };
  return { dispatch, getState, garmin: ( ) => state.dragDropZone.garmin };
}

const token = { accessToken: "tok", expiresAtMs: Date.now( ) + 60 * 60 * 1000 };
const walk = { id: 1, name: "Morning Walk", hasTrack: true };

beforeEach( ( ) => {
  jest.clearAllMocks( );
} );

describe( "connectGarmin", ( ) => {
  it( "exchanges the key through the relay and loads activities", async ( ) => {
    geotrack.exchangeGarminApiKey.mockResolvedValue( token );
    geotrack.searchGarminActivities.mockResolvedValue( [walk] );
    const store = makeStore( );
    await store.dispatch( actions.connectGarmin( "key" ) );
    expect( geotrack.exchangeGarminApiKey ).toHaveBeenCalledWith( "key", { baseUrl: "/garmin_relay" } );
    expect( geotrack.searchGarminActivities.mock.calls[0][0] ).toBe( token );
    expect( store.garmin( ) ).toMatchObject( {
      token,
      activities: [walk],
      loading: false,
      error: null
    } );
  } );

  it( "shows the rejected-key error for a 401", async ( ) => {
    geotrack.exchangeGarminApiKey.mockRejectedValue( new geotrack.GarminApiError( "no", 401 ) );
    const store = makeStore( );
    await store.dispatch( actions.connectGarmin( "bad" ) );
    expect( store.garmin( ) ).toMatchObject( {
      token: null,
      loading: false,
      error: "gps_track_garmin_key_rejected"
    } );
  } );

  it( "shows a connection error otherwise", async ( ) => {
    geotrack.exchangeGarminApiKey.mockRejectedValue( new geotrack.GarminApiError( "down", 502 ) );
    const store = makeStore( );
    await store.dispatch( actions.connectGarmin( "key" ) );
    expect( store.garmin( ).error ).toBe( "gps_track_garmin_connection_error" );
  } );
} );

describe( "openGarminImport", ( ) => {
  it( "drops an expired token so the key form shows", ( ) => {
    const store = makeStore( { show: false, token: { accessToken: "old", expiresAtMs: 0 }, activities: [walk] } );
    store.dispatch( actions.openGarminImport( ) );
    expect( store.garmin( ) ).toMatchObject( { show: true, token: null, activities: null } );
    expect( geotrack.searchGarminActivities ).not.toHaveBeenCalled( );
  } );

  it( "loads activities for a live token", ( ) => {
    geotrack.searchGarminActivities.mockResolvedValue( [] );
    const store = makeStore( { show: false, token } );
    store.dispatch( actions.openGarminImport( ) );
    expect( geotrack.searchGarminActivities ).toHaveBeenCalled( );
  } );
} );

describe( "loadGarminActivities", ( ) => {
  it( "appends the next page", async ( ) => {
    geotrack.searchGarminActivities.mockResolvedValue( [{ id: 2 }] );
    const store = makeStore( { token, activities: [walk] } );
    await store.dispatch( actions.loadGarminActivities( { more: true } ) );
    expect( geotrack.searchGarminActivities.mock.calls[0][1].start ).toBe( 1 );
    expect( store.garmin( ).activities ).toEqual( [walk, { id: 2 }] );
    expect( store.garmin( ).hasMore ).toBe( false );
  } );
} );

describe( "importGarminActivity", ( ) => {
  it( "loads the track and closes the window", async ( ) => {
    geotrack.downloadGarminActivityFile.mockResolvedValue( { fileName: "1.gpx", format: "gpx", content: GPX } );
    const store = makeStore( { token } );
    // The browser DOMParser parses GPX in jsdom
    await store.dispatch( actions.importGarminActivity( walk ) );
    expect( geotrack.downloadGarminActivityFile ).toHaveBeenCalledWith( token, 1, { baseUrl: "/garmin_relay" } );
    expect( store.getState( ).dragDropZone.gpsTrack ).toMatchObject( { fileName: "Morning Walk" } );
    expect( store.getState( ).dragDropZone.gpsTrack.points ).toHaveLength( 1 );
    expect( store.garmin( ) ).toMatchObject( { show: false, importingId: null } );
  } );

  it( "keeps the window open with an error when the download fails", async ( ) => {
    geotrack.downloadGarminActivityFile.mockRejectedValue( new geotrack.GarminApiError( "x", 500 ) );
    const store = makeStore( { token } );
    await store.dispatch( actions.importGarminActivity( walk ) );
    expect( store.garmin( ) ).toMatchObject( {
      show: true,
      importingId: null,
      error: "gps_track_garmin_import_error"
    } );
    expect( store.getState( ).dragDropZone.gpsTrack ).toBeNull( );
  } );
} );

import inatjs from "inaturalistjs";
import thunkMiddleware from "redux-thunk";
import { createStore, applyMiddleware, combineReducers } from "redux";
import reducer, { fetchFeatureFlags, setCurrentUser, updateCurrentUser } from "./config";
import Config from "../models/config";
import CurrentUser from "../models/current_user";

// shared/util pulls in browser-only deps jest cannot transform; the duck only needs fetch.
jest.mock( "../util", ( ) => ( { fetch: jest.fn( ) } ) );
jest.mock( "inaturalistjs", ( ) => ( {
  setConfig: jest.fn( ),
  feature_flags: { get: jest.fn( ) }
} ) );

const API_V2_URL = "http://localhost:4000/v2";

describe( "fetchFeatureFlags", ( ) => {
  let meta;
  let dispatched;
  let state;

  const dispatch = action => {
    dispatched.push( action );
    return action;
  };
  const getState = ( ) => state;
  const stateWith = attrs => ( {
    config: new Config( { currentUser: new CurrentUser( { id: 1 } ), ...attrs } )
  } );

  beforeEach( ( ) => {
    meta = document.createElement( "meta" );
    meta.setAttribute( "name", "config:inaturalist_api_url_v2" );
    meta.setAttribute( "content", API_V2_URL );
    document.head.appendChild( meta );
    dispatched = [];
    state = stateWith( );
    inatjs.feature_flags.get.mockResolvedValue( {
      flags: { client_smoke_test: true },
      experiments: { hello_world: null }
    } );
  } );

  afterEach( ( ) => {
    meta.remove( );
  } );

  it( "loads the flag map onto the current user", async ( ) => {
    await fetchFeatureFlags( )( dispatch, getState );
    expect( inatjs.feature_flags.get ).toHaveBeenCalledTimes( 1 );
    expect( dispatched ).toEqual( [
      updateCurrentUser( { featureFlags: { client_smoke_test: true } } )
    ] );
    const next = reducer( state.config, dispatched[0] );
    expect( next.currentUser ).toBeInstanceOf( CurrentUser );
    expect( next.currentUser.featureFlagEnabled( "client_smoke_test" ) ).toBe( true );
  } );

  it( "does not call the API for an anonymous visitor", async ( ) => {
    state = { config: new Config( { } ) };
    await fetchFeatureFlags( )( dispatch, getState );
    expect( inatjs.feature_flags.get ).not.toHaveBeenCalled( );
    expect( dispatched ).toEqual( [] );
  } );

  // The endpoint ships with inaturalistjs WEB-1168; older installs must not throw.
  it( "does nothing when inaturalistjs has no feature_flags endpoint", async ( ) => {
    const endpoint = inatjs.feature_flags;
    delete inatjs.feature_flags;
    try {
      await fetchFeatureFlags( )( dispatch, getState );
      expect( dispatched ).toEqual( [] );
    } finally {
      inatjs.feature_flags = endpoint;
    }
  } );

  it( "fails closed with an empty map when the request fails", async ( ) => {
    inatjs.feature_flags.get.mockRejectedValue( new Error( "boom" ) );
    await fetchFeatureFlags( )( dispatch, getState );
    expect( dispatched ).toEqual( [updateCurrentUser( { featureFlags: { } } )] );
    const next = reducer( state.config, dispatched[0] );
    expect( next.currentUser.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
  } );

  it( "defaults to an empty map when the response has no flags key", async ( ) => {
    inatjs.feature_flags.get.mockResolvedValue( { } );
    await fetchFeatureFlags( )( dispatch, getState );
    expect( dispatched ).toEqual( [updateCurrentUser( { featureFlags: { } } )] );
  } );

  // feature_flags only exists on API v2; the client is pointed there and left there.
  it( "points inaturalistjs at API v2 from the v2 meta tag", async ( ) => {
    await fetchFeatureFlags( )( dispatch, getState );
    expect( inatjs.setConfig.mock.calls ).toEqual( [
      [{ apiURL: API_V2_URL, writeApiURL: API_V2_URL }]
    ] );
    expect( inatjs.feature_flags.get ).toHaveBeenCalledTimes( 1 );
  } );

  it( "does nothing on a layout without the v2 meta tag", async ( ) => {
    meta.remove( );
    await fetchFeatureFlags( )( dispatch, getState );
    expect( inatjs.setConfig ).not.toHaveBeenCalled( );
    expect( inatjs.feature_flags.get ).not.toHaveBeenCalled( );
    expect( dispatched ).toEqual( [] );
  } );
} );

// End to end through a real store, the way shared_store wires it: the first flag read on the
// current user fires the API request, and the response lands back on the same instance.
describe( "lazy loading through the store", ( ) => {
  let meta;
  let store;

  const flushPromises = ( ) => new Promise( resolve => { setTimeout( resolve, 0 ); } );
  const currentUser = ( ) => store.getState( ).config.currentUser;

  beforeEach( ( ) => {
    meta = document.createElement( "meta" );
    meta.setAttribute( "name", "config:inaturalist_api_url_v2" );
    meta.setAttribute( "content", API_V2_URL );
    document.head.appendChild( meta );
    inatjs.feature_flags.get.mockResolvedValue( { flags: { client_smoke_test: true } } );
    store = createStore(
      combineReducers( { config: reducer } ),
      applyMiddleware( thunkMiddleware )
    );
    store.dispatch( setCurrentUser( { id: 1, login: "someone" } ) );
  } );

  afterEach( ( ) => {
    meta.remove( );
  } );

  it( "loads flags from the API the first time one is read", async ( ) => {
    expect( inatjs.feature_flags.get ).not.toHaveBeenCalled( );
    expect( currentUser( ).featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
    expect( inatjs.feature_flags.get ).toHaveBeenCalledTimes( 1 );
    await flushPromises( );
    expect( currentUser( ).featureFlagEnabled( "client_smoke_test" ) ).toBe( true );
  } );

  it( "notifies store subscribers when the flags arrive, so connected components re-render", async ( ) => {
    const listener = jest.fn( );
    store.subscribe( listener );
    currentUser( ).featureFlagEnabled( "client_smoke_test" );
    expect( listener ).not.toHaveBeenCalled( );
    await flushPromises( );
    expect( listener ).toHaveBeenCalledTimes( 1 );
  } );

  it( "requests the flags only once per user", async ( ) => {
    currentUser( ).featureFlagEnabled( "client_smoke_test" );
    currentUser( ).featureFlagEnabled( "client_other" );
    await flushPromises( );
    currentUser( ).featureFlagEnabled( "client_smoke_test" );
    expect( inatjs.feature_flags.get ).toHaveBeenCalledTimes( 1 );
  } );

  it( "keeps the loaded flags through later current user updates", async ( ) => {
    currentUser( ).featureFlagEnabled( "client_smoke_test" );
    await flushPromises( );
    store.dispatch( updateCurrentUser( { name: "Someone" } ) );
    expect( currentUser( ).name ).toBe( "Someone" );
    expect( currentUser( ).featureFlagEnabled( "client_smoke_test" ) ).toBe( true );
    expect( inatjs.feature_flags.get ).toHaveBeenCalledTimes( 1 );
  } );

  it( "does not request flags for an anonymous visitor", ( ) => {
    store = createStore(
      combineReducers( { config: reducer } ),
      applyMiddleware( thunkMiddleware )
    );
    expect( store.getState( ).config.currentUser ).toBeUndefined( );
    expect( inatjs.feature_flags.get ).not.toHaveBeenCalled( );
  } );
} );

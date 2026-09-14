import { googleMapsIsLoaded } from "./google_maps";

describe( "googleMapsIsLoaded", ( ) => {
  afterEach( ( ) => {
    delete global.google;
  } );

  it( "is false when google is undefined (synchronous loader blocked)", ( ) => {
    delete global.google;
    expect( googleMapsIsLoaded( ) ).toBe( false );
  } );

  it( "is false for the async bootstrap stub (async loader blocked)", ( ) => {
    global.google = { maps: { importLibrary: ( ) => Promise.reject( new Error( "blocked" ) ) } };
    expect( googleMapsIsLoaded( ) ).toBe( false );
  } );

  it( "is false when google.maps is missing", ( ) => {
    global.google = { };
    expect( googleMapsIsLoaded( ) ).toBe( false );
  } );

  it( "is true once the maps library has loaded", ( ) => {
    global.google = {
      maps: {
        Map: function Map( ) { },
        MapTypeId: { TERRAIN: "terrain" }
      }
    };
    expect( googleMapsIsLoaded( ) ).toBe( true );
  } );
} );

import CurrentUser from "./current_user";

describe( "CurrentUser", ( ) => {
  describe( "featureFlagEnabled", ( ) => {
    it( "is true for a flag the server resolved as on", async ( ) => {
      const user = new CurrentUser( { id: 1, featureFlags: { client_smoke_test: true } } );
      expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( true );
    } );

    it( "is false for a flag the server resolved as off", async ( ) => {
      const user = new CurrentUser( { id: 1, featureFlags: { client_smoke_test: false } } );
      expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
    } );

    it( "is false for a flag that is not in the map", async ( ) => {
      const user = new CurrentUser( { id: 1, featureFlags: { client_smoke_test: true } } );
      expect( await user.featureFlagEnabled( "typo_flag" ) ).toBe( false );
    } );

    // Fails closed before the map has loaded.
    it( "is false when no flags have been loaded", async ( ) => {
      const user = new CurrentUser( { id: 1 } );
      expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
    } );

    it( "is false when the map is not an object", async ( ) => {
      expect( await new CurrentUser( { id: 1, featureFlags: null } ).featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
      expect( await new CurrentUser( { id: 1, featureFlags: "x" } ).featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
    } );

    it( "reads flags merged onto an existing instance", async ( ) => {
      const user = new CurrentUser( { id: 1 } );
      Object.assign( user, { featureFlags: { client_smoke_test: true } } );
      expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( true );
    } );

    it( "leaves the derived booleans alone", ( ) => {
      const user = new CurrentUser( { id: 1, featureFlags: { client_smoke_test: true } } );
      expect( user.loggedIn ).toBe( true );
      expect( user.isAdmin ).toBe( false );
    } );

    describe( "lazy loading", ( ) => {
      it( "waits for the loader on the first read", async ( ) => {
        const user = new CurrentUser( { id: 1 } );
        user.loadFeatureFlags = jest.fn( async ( ) => {
          user.featureFlags = { client_smoke_test: true };
        } );
        expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( true );
        expect( user.loadFeatureFlags ).toHaveBeenCalledTimes( 1 );
      } );

      it( "asks only once for concurrent reads", async ( ) => {
        const user = new CurrentUser( { id: 1 } );
        user.loadFeatureFlags = jest.fn( async ( ) => {
          user.featureFlags = { client_smoke_test: true };
        } );
        expect( await Promise.all( [
          user.featureFlagEnabled( "client_smoke_test" ),
          user.featureFlagEnabled( "client_other" )
        ] ) ).toEqual( [true, false] );
        expect( user.loadFeatureFlags ).toHaveBeenCalledTimes( 1 );
      } );

      it( "asks only once when the loader leaves the map missing", async ( ) => {
        const user = new CurrentUser( { id: 1 } );
        user.loadFeatureFlags = jest.fn( ( ) => Promise.resolve( ) );
        expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
        expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
        expect( user.loadFeatureFlags ).toHaveBeenCalledTimes( 1 );
      } );

      it( "does not ask again once the map is present, even if empty", async ( ) => {
        const user = new CurrentUser( { id: 1, featureFlags: { } } );
        user.loadFeatureFlags = jest.fn( );
        await user.featureFlagEnabled( "client_smoke_test" );
        expect( user.loadFeatureFlags ).not.toHaveBeenCalled( );
      } );

      it( "is false when the loader fails", async ( ) => {
        const user = new CurrentUser( { id: 1 } );
        user.loadFeatureFlags = jest.fn( ( ) => Promise.reject( new Error( "boom" ) ) );
        expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
      } );

      it( "works without a loader", async ( ) => {
        const user = new CurrentUser( { id: 1 } );
        expect( await user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
      } );
    } );
  } );
} );

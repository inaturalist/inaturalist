import CurrentUser from "./current_user";

describe( "CurrentUser", ( ) => {
  describe( "featureFlagEnabled", ( ) => {
    it( "is true for a flag the server resolved as on", ( ) => {
      const user = new CurrentUser( { id: 1, featureFlags: { client_smoke_test: true } } );
      expect( user.featureFlagEnabled( "client_smoke_test" ) ).toBe( true );
    } );

    it( "is false for a flag the server resolved as off", ( ) => {
      const user = new CurrentUser( { id: 1, featureFlags: { client_smoke_test: false } } );
      expect( user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
    } );

    it( "is false for a flag that is not in the map", ( ) => {
      const user = new CurrentUser( { id: 1, featureFlags: { client_smoke_test: true } } );
      expect( user.featureFlagEnabled( "typo_flag" ) ).toBe( false );
    } );

    // Must fail closed before fetchFeatureFlags has run, and for layouts that never load flags.
    it( "is false when no flags have been loaded", ( ) => {
      const user = new CurrentUser( { id: 1 } );
      expect( user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
    } );

    it( "is false when the map is not an object", ( ) => {
      expect( new CurrentUser( { id: 1, featureFlags: null } ).featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
      expect( new CurrentUser( { id: 1, featureFlags: "x" } ).featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
    } );

    // The config reducer's UPDATE_CURRENT_USER merges with Object.assign and never re-runs the
    // constructor, so the check has to read the instance at call time.
    it( "reads flags merged onto an existing instance", ( ) => {
      const user = new CurrentUser( { id: 1 } );
      Object.assign( user, { featureFlags: { client_smoke_test: true } } );
      expect( user.featureFlagEnabled( "client_smoke_test" ) ).toBe( true );
    } );

    it( "leaves the derived booleans alone", ( ) => {
      const user = new CurrentUser( { id: 1, featureFlags: { client_smoke_test: true } } );
      expect( user.loggedIn ).toBe( true );
      expect( user.isAdmin ).toBe( false );
    } );

    // The config duck attaches loadFeatureFlags; the first read asks it to fetch and answers
    // off until the map arrives, so no page has to remember to load flags up front.
    describe( "lazy loading", ( ) => {
      it( "asks the loader for flags on the first read", ( ) => {
        const user = new CurrentUser( { id: 1 } );
        user.loadFeatureFlags = jest.fn( );
        expect( user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
        expect( user.loadFeatureFlags ).toHaveBeenCalledTimes( 1 );
      } );

      it( "asks only once while the map is still missing", ( ) => {
        const user = new CurrentUser( { id: 1 } );
        user.loadFeatureFlags = jest.fn( );
        user.featureFlagEnabled( "client_smoke_test" );
        user.featureFlagEnabled( "client_other" );
        expect( user.loadFeatureFlags ).toHaveBeenCalledTimes( 1 );
      } );

      it( "does not ask again once the map is present, even if empty", ( ) => {
        const user = new CurrentUser( { id: 1, featureFlags: { } } );
        user.loadFeatureFlags = jest.fn( );
        user.featureFlagEnabled( "client_smoke_test" );
        expect( user.loadFeatureFlags ).not.toHaveBeenCalled( );
      } );

      it( "works without a loader", ( ) => {
        const user = new CurrentUser( { id: 1 } );
        expect( user.featureFlagEnabled( "client_smoke_test" ) ).toBe( false );
      } );
    } );
  } );
} );

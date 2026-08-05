import featureFlagEnabled from "./feature_flags";

// CONFIG is a global set by an inline script in the layout, so these tests set
// and clear it the way the page does rather than importing anything.
describe( "featureFlagEnabled", ( ) => {
  afterEach( ( ) => {
    delete global.CONFIG;
  } );

  it( "is true for a flag the server resolved as on", ( ) => {
    global.CONFIG = { feature_flags: { demo_banner: true } };
    expect( featureFlagEnabled( "demo_banner" ) ).toBe( true );
  } );

  it( "is false for a flag the server resolved as off", ( ) => {
    global.CONFIG = { feature_flags: { demo_banner: false } };
    expect( featureFlagEnabled( "demo_banner" ) ).toBe( false );
  } );

  // A flag missing from FeatureFlagging::CLIENT_FLAGS, or simply misspelled
  // here, must read as off rather than undefined.
  it( "is false for a flag that is not in the payload", ( ) => {
    global.CONFIG = { feature_flags: { demo_banner: true } };
    expect( featureFlagEnabled( "typo_banner" ) ).toBe( false );
  } );

  // The payload is absent on any page whose layout predates it, and CONFIG
  // itself is undefined in contexts like the uploader's isolated bundles. Both
  // have to fail closed instead of throwing.
  it( "is false when the payload is missing", ( ) => {
    global.CONFIG = { content_freeze_enabled: false };
    expect( featureFlagEnabled( "demo_banner" ) ).toBe( false );
  } );

  it( "is false when CONFIG is undefined", ( ) => {
    expect( featureFlagEnabled( "demo_banner" ) ).toBe( false );
  } );
} );

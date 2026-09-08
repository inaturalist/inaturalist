import featureFlagEnabled from "./feature_flags";

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

  it( "is false for a flag that is not in the payload", ( ) => {
    global.CONFIG = { feature_flags: { demo_banner: true } };
    expect( featureFlagEnabled( "typo_banner" ) ).toBe( false );
  } );

  // Must fail closed for old layouts and isolated bundle contexts.
  it( "is false when the payload is missing", ( ) => {
    global.CONFIG = { content_freeze_enabled: false };
    expect( featureFlagEnabled( "demo_banner" ) ).toBe( false );
  } );

  it( "is false when CONFIG is undefined", ( ) => {
    expect( featureFlagEnabled( "demo_banner" ) ).toBe( false );
  } );
} );

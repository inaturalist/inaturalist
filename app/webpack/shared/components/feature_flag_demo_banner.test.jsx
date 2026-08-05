import React from "react";
import { render, screen } from "@testing-library/react";
import FeatureFlagDemoBanner from "./feature_flag_demo_banner";

// Proves the client-side half of the WEB-1074 demo: the resolved flag value that
// the server puts in the CONFIG payload is what decides whether this renders.
// Delete with the rest of the demo.
describe( "FeatureFlagDemoBanner", ( ) => {
  const setFlags = flags => {
    global.CONFIG = { feature_flags: flags };
  };

  beforeAll( ( ) => {
    global.I18n = { t: key => `translated:${key}` };
  } );

  afterEach( ( ) => {
    delete global.CONFIG;
  } );

  it( "renders when the flag is on for this visitor", ( ) => {
    setFlags( { demo_banner: true } );
    render( <FeatureFlagDemoBanner /> );
    expect( screen.getByText( "translated:feature_flag_demo_banner" ) ).toBeInTheDocument( );
  } );

  it( "renders nothing when the flag is off", ( ) => {
    setFlags( { demo_banner: false } );
    const { container } = render( <FeatureFlagDemoBanner /> );
    expect( container ).toBeEmptyDOMElement( );
  } );

  // The whole point of gating on the server-resolved value: a client that never
  // received a payload must not show the feature.
  it( "renders nothing when there is no flag payload at all", ( ) => {
    const { container } = render( <FeatureFlagDemoBanner /> );
    expect( container ).toBeEmptyDOMElement( );
  } );
} );

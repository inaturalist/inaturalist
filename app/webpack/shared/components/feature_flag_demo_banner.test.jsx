import React from "react";
import { render, screen } from "@testing-library/react";
import FeatureFlagDemoBanner from "./feature_flag_demo_banner";

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

  it( "renders nothing when there is no flag payload at all", ( ) => {
    const { container } = render( <FeatureFlagDemoBanner /> );
    expect( container ).toBeEmptyDOMElement( );
  } );
} );

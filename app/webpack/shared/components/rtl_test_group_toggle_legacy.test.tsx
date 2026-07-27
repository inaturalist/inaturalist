import React from "react";
import { render } from "@testing-library/react";
import RtlTestGroupToggleLegacy from "./rtl_test_group_toggle_legacy";

// test_group_toggle reads the CSRF token off the DOM through the jQuery global,
// which Rails injects at runtime and jest.setup does not provide.
beforeAll( ( ) => {
  ( global as unknown as Record<string, unknown> ).$ = ( ) => ( { attr: ( ) => "stub" } );
} );

const eligible = {
  currentUser: {
    id: 1, roles: ["curator"], locale: "en", testGroups: ""
  }
};
const ineligible = {
  currentUser: {
    id: 2, roles: [], locale: "en", testGroups: ""
  }
};

describe( "RtlTestGroupToggleLegacy", ( ) => {
  it( "wraps the toggle in the legacy bootstrap grid", ( ) => {
    const { container } = render( <RtlTestGroupToggleLegacy config={eligible} /> );
    const toggle = container.querySelector( ".TestGroupToggle" );
    expect( toggle ).not.toBeNull( );
    expect( toggle?.closest( ".row" ) ).not.toBeNull( );
    expect( toggle?.closest( ".container" ) ).not.toBeNull( );
  } );

  it( "renders nothing when the viewer is not eligible for the rtl test", ( ) => {
    const { container } = render( <RtlTestGroupToggleLegacy config={ineligible} /> );
    expect( container ).toBeEmptyDOMElement( );
  } );

  it( "renders nothing when there is no current user", ( ) => {
    const { container } = render( <RtlTestGroupToggleLegacy config={{}} /> );
    expect( container ).toBeEmptyDOMElement( );
  } );
} );

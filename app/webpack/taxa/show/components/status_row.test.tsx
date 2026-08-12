import React from "react";
import { render } from "@testing-library/react";
import StatusRow from "./status_row";

jest.mock( "./status_header", ( ) => ( {
  __esModule: true,
  default: ( ) => <div data-testid="conservation-status" />
} ) );
jest.mock( "../containers/establishment_header_container", ( ) => ( {
  __esModule: true,
  default: ( ) => <div data-testid="establishment-means" />
} ) );

describe( "StatusRow", ( ) => {
  it( "renders nothing without statuses", ( ) => {
    const { container } = render( <StatusRow /> );
    expect( container ).toBeEmptyDOMElement( );
  } );

  it( "wraps a lone conservation status in the status-row container", ( ) => {
    const { container, getByTestId } = render( <StatusRow conservationStatus={{}} /> );
    expect( getByTestId( "conservation-status" ) ).toBeInTheDocument( );
    expect( container.querySelector( ".status-row .status-row-item" ) )
      .toContainElement( getByTestId( "conservation-status" ) );
  } );

  it( "wraps lone establishment means in the status-row container", ( ) => {
    const { container, getByTestId } = render( <StatusRow establishmentMeans={{}} /> );
    expect( container.querySelector( ".status-row .status-row-item" ) )
      .toContainElement( getByTestId( "establishment-means" ) );
  } );

  it( "renders both statuses as items of one status-row", ( ) => {
    const { container } = render(
      <StatusRow conservationStatus={{}} establishmentMeans={{}} />
    );
    expect( container.querySelectorAll( ".status-row" ) ).toHaveLength( 1 );
    expect( container.querySelectorAll( ".status-row-item" ) ).toHaveLength( 2 );
  } );
} );

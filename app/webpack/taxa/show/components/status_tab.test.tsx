import React from "react";
import { render, screen } from "@testing-library/react";
import StatusTab from "./status_tab";
import StatusTabLegacy from "./status_tab_legacy";

jest.mock( "../../shared/util", ( ) => ( {
  urlForTaxon: ( ) => null,
  isCuratorOrAdmin: ( ) => false
} ) );
jest.mock( "../../../shared/components/split_taxon", ( ) => ( {
  __esModule: true,
  default: ( ) => null
} ) );
jest.mock( "../../../shared/components/user_text", ( ) => ( {
  __esModule: true,
  default: ( ) => null
} ) );

const conservationStatus = ( status: string, text: string ) => ( {
  id: 1,
  status,
  iucn: 10,
  statusText: ( ) => text,
  iucnStatusCode: ( ) => "LC"
} );

describe.each( [
  ["StatusTab", StatusTab],
  ["StatusTabLegacy", StatusTabLegacy]
] )( "%s status text", ( _name, Component ) => {
  const renderStatus = ( status: string, text: string ) => render(
    <Component statuses={[conservationStatus( status, text )]} taxon={{ id: 1 }} />
  );

  it( "renders statuses that start with a regex quantifier", ( ) => {
    renderStatus( "* Ungefährdet", "* Ungefährdet" );
    expect( screen.getByText( "* Ungefährdet" ) ).toBeInTheDocument( );
  } );

  it( "appends the status code when the text lacks it", ( ) => {
    renderStatus( "S3", "vulnerable" );
    expect( screen.getByText( "vulnerable (S3)" ) ).toBeInTheDocument( );
  } );

  it( "treats regex metacharacters in the status literally", ( ) => {
    renderStatus( "S1.", "S1x" );
    expect( screen.getByText( "S1x (S1.)" ) ).toBeInTheDocument( );
  } );
} );

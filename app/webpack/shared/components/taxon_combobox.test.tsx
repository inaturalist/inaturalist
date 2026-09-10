import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { axe } from "jest-axe";
import inaturalistjs from "inaturalistjs";
import TaxonCombobox from "./taxon_combobox";

jest.mock( "inaturalistjs", ( ) => ( {
  taxa: { autocomplete: jest.fn( ) },
  computervision: { score_observation: jest.fn( ) }
} ) );

jest.mock( "../util", ( ) => ( { updateSession: jest.fn( ) } ) );

const mocked = inaturalistjs as unknown as {
  taxa: { autocomplete: jest.Mock };
  computervision: { score_observation: jest.Mock };
};

beforeEach( ( ) => {
  mocked.taxa.autocomplete.mockResolvedValue( {
    results: [
      {
        id: 42, name: "Vulpes vulpes", rank: "species", rank_level: 10
      },
      {
        id: 43, name: "Vulpes lagopus", rank: "species", rank_level: 10
      }
    ]
  } );
  mocked.computervision.score_observation.mockResolvedValue( {
    common_ancestor: {
      taxon: {
        id: 1, name: "Canidae", rank: "family", rank_level: 30
      }
    },
    results: [
      {
        taxon: {
          id: 42, name: "Vulpes vulpes", rank: "species", rank_level: 10
        },
        vision_score: 0.9,
        frequency_score: 3
      }
    ]
  } );
} );

const setup = ( props: Partial<React.ComponentProps<typeof TaxonCombobox>> = { } ) => render(
  <TaxonCombobox
    onSelect={props.onSelect || ( ( ) => undefined )}
    visionParams={{ observationID: 7 }}
    searchExternal
    {...props}
  />
);

describe( "TaxonCombobox", ( ) => {
  it( "shows vision suggestions under their category headings when focused", async ( ) => {
    setup( );
    await userEvent.click( screen.getByRole( "combobox" ) );
    await waitFor( ( ) => expect( screen.getAllByRole( "option" ) ).toHaveLength( 2 ) );
    expect( screen.getByText( "here_are_our_top_suggestions" ) ).toBeInTheDocument( );
    expect( screen.getByText( "visually_similar / expected_nearby" ) ).toBeInTheDocument( );
  } );

  it( "searches taxa once the user types and offers external providers last", async ( ) => {
    setup( );
    await userEvent.type( screen.getByRole( "combobox" ), "vulpes" );
    await waitFor( ( ) => expect( screen.getAllByRole( "option" ) ).toHaveLength( 3 ) );
    const options = screen.getAllByRole( "option" );
    expect( options[2] ).toHaveTextContent( "search_external_name_providers" );
  } );

  it( "reports the chosen taxon and fills the hidden taxon_id", async ( ) => {
    const onSelect = jest.fn( );
    const { container } = setup( { onSelect } );
    await userEvent.type( screen.getByRole( "combobox" ), "vulpes" );
    await waitFor( ( ) => expect( screen.getAllByRole( "option" ) ).toHaveLength( 3 ) );
    await userEvent.click( screen.getByText( "Vulpes lagopus" ) );
    expect( onSelect ).toHaveBeenCalledWith( expect.objectContaining( { id: 43 } ) );
    expect( container.querySelector( "input[name='taxon_id']" ) ).toHaveValue( "43" );
    expect( screen.getByRole( "combobox" ) ).toHaveValue( "Vulpes lagopus" );
  } );

  it( "links the selected taxon chip to its taxon page", async ( ) => {
    setup( );
    await userEvent.type( screen.getByRole( "combobox" ), "vulpes" );
    await waitFor( ( ) => expect( screen.getAllByRole( "option" ) ).toHaveLength( 3 ) );
    await userEvent.click( screen.getByText( "Vulpes lagopus" ) );
    expect( screen.getByRole( "link", { name: "view" } ) ).toHaveAttribute( "href", "/taxa/43" );
  } );

  it( "closes the suggestions once a taxon is chosen", async ( ) => {
    setup( );
    await userEvent.click( screen.getByRole( "combobox" ) );
    await screen.findAllByRole( "option" );
    await userEvent.click( screen.getByText( "Vulpes vulpes" ) );
    await waitFor( ( ) => expect( screen.queryByRole( "listbox" ) ).not.toBeInTheDocument( ) );
  } );

  it( "clears the selection", async ( ) => {
    const onSelect = jest.fn( );
    const { container } = setup( { onSelect } );
    await userEvent.click( screen.getByRole( "combobox" ) );
    await screen.findAllByRole( "option" );
    await userEvent.click( screen.getByText( "Vulpes vulpes" ) );
    await userEvent.click( screen.getByRole( "button", { name: "clear" } ) );
    expect( screen.getByRole( "combobox" ) ).toHaveValue( "" );
    expect( container.querySelector( "input[name='taxon_id']" ) ).toHaveValue( "" );
    expect( onSelect ).toHaveBeenLastCalledWith( null );
  } );

  it( "has no axe violations with suggestions open", async ( ) => {
    const { container } = setup( );
    await userEvent.click( screen.getByRole( "combobox" ) );
    await screen.findAllByRole( "option" );
    expect( await axe( container ) ).toHaveNoViolations( );
  } );

  it( "has no axe violations after a taxon is chosen (chip link is outside the listbox)", async ( ) => {
    const { container } = setup( );
    await userEvent.type( screen.getByRole( "combobox" ), "vulpes" );
    await waitFor( ( ) => expect( screen.getAllByRole( "option" ) ).toHaveLength( 3 ) );
    await userEvent.click( screen.getByText( "Vulpes lagopus" ) );
    expect( await axe( container ) ).toHaveNoViolations( );
  } );
} );

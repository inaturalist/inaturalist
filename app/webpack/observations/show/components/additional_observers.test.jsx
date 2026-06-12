import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import AdditionalObservers from "./additional_observers";

// Replace the real autocomplete (jQuery-driven) with a button that fires
// afterSelect, so we can assert wiring without the jQuery plugin.
jest.mock( "../../identify/components/user_autocomplete", ( ) => {
  // eslint-disable-next-line global-require
  const PropTypes = require( "prop-types" );
  const MockAutocomplete = ( { afterSelect } ) => (
    <button
      type="button"
      data-testid="user-autocomplete"
      onClick={( ) => afterSelect( { item: { user_id: 7, id: 7, login: "picked" } } )}
    >
      autocomplete
    </button>
  );
  MockAutocomplete.propTypes = { afterSelect: PropTypes.func };
  return MockAutocomplete;
} );

const observation = {
  id: 42,
  user: { id: 1, login: "creator" },
  additional_observers: [
    { user: { id: 2, login: "alice" } },
    { user: { id: 3, login: "bob" } }
  ]
};

const defaultProps = ( overrides = {} ) => ( {
  config: { currentUser: { id: 1 } },
  observation,
  viewerIsObserver: true,
  addAdditionalObserver: jest.fn( ),
  removeAdditionalObserver: jest.fn( ),
  ...overrides
} );

describe( "AdditionalObservers", ( ) => {
  it( "lists each additional observer's login", ( ) => {
    render( <AdditionalObservers {...defaultProps( )} /> );
    expect( screen.getByText( "alice" ) ).toBeInTheDocument( );
    expect( screen.getByText( "bob" ) ).toBeInTheDocument( );
  } );

  it( "invokes removeAdditionalObserver when a remove button is clicked", async ( ) => {
    const removeAdditionalObserver = jest.fn( );
    render( <AdditionalObservers {...defaultProps( { removeAdditionalObserver } )} /> );
    const removeButtons = screen.getAllByRole( "button", { name: /remove/i } );
    await userEvent.click( removeButtons[0] );
    expect( removeAdditionalObserver ).toHaveBeenCalledWith( 2 );
  } );

  it( "renders the autocomplete picker when the viewer is the observer", ( ) => {
    render( <AdditionalObservers {...defaultProps( )} /> );
    expect( screen.getByTestId( "user-autocomplete" ) ).toBeInTheDocument( );
  } );

  it( "renders nothing when the viewer is not the observer", ( ) => {
    const { container } = render(
      <AdditionalObservers {...defaultProps( { viewerIsObserver: false } )} />
    );
    expect( container ).toBeEmptyDOMElement( );
    expect( screen.queryByTestId( "user-autocomplete" ) ).not.toBeInTheDocument( );
  } );

  it( "passes the selected user to addAdditionalObserver", async ( ) => {
    const addAdditionalObserver = jest.fn( );
    render( <AdditionalObservers {...defaultProps( { addAdditionalObserver } )} /> );
    await userEvent.click( screen.getByTestId( "user-autocomplete" ) );
    expect( addAdditionalObserver ).toHaveBeenCalledTimes( 1 );
    expect( addAdditionalObserver.mock.calls[0][0].id ).toEqual( 7 );
  } );
} );

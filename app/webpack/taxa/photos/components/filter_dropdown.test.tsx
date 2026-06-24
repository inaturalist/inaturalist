import React from "react";
import {
  render, screen, fireEvent, within
} from "@testing-library/react";
import FilterDropdown from "./filter_dropdown";

// --- Mocks --------------------------------------------------------------

// The real Dropdown only mounts its menu when open and wires onSelect via
// context. These stubs render every MenuItem as a button that calls the parent
// Dropdown's onSelect with its eventKey — letting us assert the exact callback
// argument (incl. a non-string eventKey).
jest.mock( "react-bootstrap", ( ) => {
  // eslint-disable-next-line global-require, @typescript-eslint/no-var-requires, no-shadow
  const React = require( "react" );
  const SelectContext = React.createContext( undefined );
  const Dropdown = Object.assign(
    ( props: { id?: string; onSelect?: ( key: unknown ) => void; children?: React.ReactNode } ) => (
      <div data-testid={`dropdown-${props.id}`}>
        <SelectContext.Provider value={props.onSelect}>
          { props.children }
        </SelectContext.Provider>
      </div>
    ),
    {
      Toggle: ( props: { children?: React.ReactNode } ) => (
        <div data-testid="dropdown-toggle">{ props.children }</div>
      ),
      Menu: ( props: { children?: React.ReactNode } ) => (
        <div data-testid="dropdown-menu">{ props.children }</div>
      )
    }
  );
  const MenuItem = ( props: {
    eventKey?: unknown; active?: boolean; children?: React.ReactNode;
  } ) => {
    const onSelect = React.useContext( SelectContext );
    return (
      <button
        type="button"
        role="menuitem"
        data-active={String( !!props.active )}
        onClick={( ) => { if ( onSelect ) { onSelect( props.eventKey ); } }}
      >
        { props.children }
      </button>
    );
  };
  return { __esModule: true, Dropdown, MenuItem };
} );

// --- Fixtures -----------------------------------------------------------

type Props = React.ComponentProps<typeof FilterDropdown>;

const renderDropdown = ( overrides: Partial<Props> = {} ) => render(
  <FilterDropdown
    id="sort-control"
    label="Order by"
    display="Faves"
    onSelect={jest.fn( )}
    options={[
      { value: "votes", label: "Faves" },
      { value: "created_at", label: "Date added" }
    ]}
    {...overrides}
  />
);

// --- Tests --------------------------------------------------------------

describe( "FilterDropdown", ( ) => {
  it( "renders the label and current display in the toggle", ( ) => {
    renderDropdown( { label: "Order by", display: "Faves" } );
    expect( screen.getByTestId( "dropdown-toggle" ) ).toHaveTextContent( "Order by: Faves" );
  } );

  it( "renders one MenuItem per option", ( ) => {
    renderDropdown( );
    expect( screen.getAllByRole( "menuitem" ) ).toHaveLength( 2 );
    expect( screen.getByRole( "menuitem", { name: "Faves" } ) ).toBeInTheDocument( );
    expect( screen.getByRole( "menuitem", { name: "Date added" } ) ).toBeInTheDocument( );
  } );

  it( "marks the option matching selected active", ( ) => {
    renderDropdown( { selected: "created_at" } );
    expect( screen.getByRole( "menuitem", { name: "Date added" } ) ).toHaveAttribute( "data-active", "true" );
    expect( screen.getByRole( "menuitem", { name: "Faves" } ) ).toHaveAttribute( "data-active", "false" );
  } );

  it( "marks the 'any' option active when nothing is selected", ( ) => {
    renderDropdown( {
      selected: undefined,
      options: [
        { value: "any", label: "Any license" },
        { value: "cc_by", label: "CC BY" }
      ]
    } );
    expect( screen.getByRole( "menuitem", { name: "Any license" } ) ).toHaveAttribute( "data-active", "true" );
    expect( screen.getByRole( "menuitem", { name: "CC BY" } ) ).toHaveAttribute( "data-active", "false" );
  } );

  it( "forwards the clicked option's eventKey to onSelect", ( ) => {
    const onSelect = jest.fn( );
    renderDropdown( { onSelect } );
    fireEvent.click( screen.getByRole( "menuitem", { name: "Date added" } ) );
    expect( onSelect ).toHaveBeenCalledWith( "created_at" );
  } );

  it( "forwards a numeric eventKey unchanged (term values are numeric ids)", ( ) => {
    const onSelect = jest.fn( );
    renderDropdown( {
      onSelect,
      options: [{ value: 10, label: "Adult" }]
    } );
    fireEvent.click( screen.getByRole( "menuitem", { name: "Adult" } ) );
    expect( onSelect ).toHaveBeenCalledWith( 10 );
  } );

  it( "renders children instead of options when provided (escape hatch)", ( ) => {
    renderDropdown( {
      options: undefined,
      children: (
        <button type="button" role="menuitem" data-testid="custom-item">custom item</button>
      )
    } );
    const menu = within( screen.getByTestId( "dropdown-menu" ) );
    expect( menu.getByTestId( "custom-item" ) ).toBeInTheDocument( );
  } );
} );

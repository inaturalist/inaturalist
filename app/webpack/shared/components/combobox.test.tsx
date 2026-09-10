import React, { useState } from "react";
import {
  fireEvent, render, screen, waitFor
} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { axe } from "jest-axe";
import Combobox, { ComboboxGroup, ComboboxOption } from "./combobox";

const OPTIONS: ComboboxOption[] = [
  { key: "1", textValue: "Vulpes vulpes", content: "Vulpes vulpes" },
  { key: "2", textValue: "Vulpes lagopus", content: "Vulpes lagopus" }
];

const GROUPED: ComboboxOption[] = [
  {
    key: "1", textValue: "Canidae", content: "Canidae", group: "ancestor"
  },
  {
    key: "2", textValue: "Vulpes vulpes", content: "Vulpes vulpes", group: "suggestions"
  }
];

const GROUPS: ComboboxGroup[] = [
  { key: "ancestor", title: "We're pretty sure this is in the family" },
  { key: "suggestions", title: "Here are our top suggestions" }
];

interface HarnessProps {
  options?: ComboboxOption[];
  groups?: ComboboxGroup[];
  onSearch?: ( query: string ) => void;
  onSelect?: ( option: ComboboxOption ) => void;
  minLength?: number;
  message?: React.ReactNode;
}

const Harness = ( {
  options = OPTIONS,
  groups,
  onSearch = ( ) => undefined,
  onSelect = ( ) => undefined,
  minLength = 1,
  message
}: HarnessProps ) => {
  const [inputValue, setInputValue] = useState( "" );
  return (
    <Combobox
      label="Species name"
      options={options}
      groups={groups}
      inputValue={inputValue}
      onInputChange={setInputValue}
      onSearch={onSearch}
      onSelect={onSelect}
      minLength={minLength}
      message={message}
      delay={0}
    />
  );
};

describe( "Combobox", ( ) => {
  it( "labels the input as a combobox", ( ) => {
    render( <Harness /> );
    expect( screen.getByRole( "combobox", { name: "Species name" } ) ).toBeInTheDocument( );
  } );

  it( "searches after the user types", async ( ) => {
    const onSearch = jest.fn( );
    render( <Harness onSearch={onSearch} /> );
    await userEvent.type( screen.getByRole( "combobox" ), "vulp" );
    await waitFor( ( ) => expect( onSearch ).toHaveBeenCalledWith( "vulp" ) );
  } );

  it( "does not search below minLength", async ( ) => {
    const onSearch = jest.fn( );
    render( <Harness onSearch={onSearch} minLength={3} /> );
    await userEvent.type( screen.getByRole( "combobox" ), "vu" );
    expect( onSearch ).not.toHaveBeenCalled( );
  } );

  it( "keeps DOM focus in the input while arrowing through options", async ( ) => {
    render( <Harness /> );
    const input = screen.getByRole( "combobox" );
    await userEvent.click( input );
    await userEvent.keyboard( "{ArrowDown}" );
    const options = screen.getAllByRole( "option" );
    expect( input ).toHaveFocus( );
    expect( input ).toHaveAttribute( "aria-activedescendant", options[0].id );
  } );

  it( "selects the focused option on Enter", async ( ) => {
    const onSelect = jest.fn( );
    render( <Harness onSelect={onSelect} /> );
    await userEvent.click( screen.getByRole( "combobox" ) );
    await userEvent.keyboard( "{ArrowDown}{Enter}" );
    expect( onSelect ).toHaveBeenCalledWith( expect.objectContaining( { key: "1" } ) );
  } );

  it( "writes the selected option's text into the input and closes the menu", async ( ) => {
    render( <Harness /> );
    const input = screen.getByRole( "combobox" );
    await userEvent.click( input );
    await userEvent.click( screen.getByText( "Vulpes lagopus" ) );
    expect( input ).toHaveValue( "Vulpes lagopus" );
    expect( screen.queryByRole( "listbox" ) ).not.toBeInTheDocument( );
  } );

  // WEB-1262: on mobile the list vanished because touching/scrolling it blurred the input.
  // react-aria keeps virtual focus on the input, so interacting with the listbox must not close it.
  it( "keeps the menu open and the input focused when interacting with the listbox", async ( ) => {
    render( <Harness minLength={0} /> );
    const input = screen.getByRole( "combobox" );
    await userEvent.click( input );
    const listbox = screen.getByRole( "listbox" );
    expect( input ).toHaveFocus( );
    fireEvent.mouseDown( screen.getAllByRole( "option" )[0] );
    fireEvent.scroll( listbox );
    expect( input ).toHaveFocus( );
    expect( screen.getByRole( "listbox" ) ).toBeInTheDocument( );
  } );

  it( "closes the menu on an interaction outside the field", async ( ) => {
    render(
      <div>
        <Harness />
        <button type="button">elsewhere</button>
      </div>
    );
    await userEvent.click( screen.getByRole( "combobox" ) );
    expect( screen.getByRole( "listbox" ) ).toBeInTheDocument( );
    await userEvent.click( screen.getByText( "elsewhere" ) );
    await waitFor( ( ) => expect( screen.queryByRole( "listbox" ) ).not.toBeInTheDocument( ) );
  } );

  it( "renders group titles as headings that are not options", async ( ) => {
    render( <Harness options={GROUPED} groups={GROUPS} /> );
    await userEvent.click( screen.getByRole( "combobox" ) );
    expect( screen.getByText( "Here are our top suggestions" ) ).toBeInTheDocument( );
    expect( screen.getAllByRole( "option" ) ).toHaveLength( 2 );
  } );

  it( "skips group titles when arrowing to the last option", async ( ) => {
    render( <Harness options={GROUPED} groups={GROUPS} /> );
    const input = screen.getByRole( "combobox" );
    await userEvent.click( input );
    await userEvent.keyboard( "{ArrowDown}{ArrowDown}" );
    const options = screen.getAllByRole( "option" );
    expect( input ).toHaveAttribute( "aria-activedescendant", options[1].id );
  } );

  it( "shows a message with no options", async ( ) => {
    render( <Harness options={[]} message="loading_suggestions" minLength={0} /> );
    await userEvent.click( screen.getByRole( "combobox" ) );
    expect( screen.getByText( "loading_suggestions" ) ).toBeInTheDocument( );
  } );

  it( "has no axe violations with the menu open", async ( ) => {
    const { container } = render( <Harness options={GROUPED} groups={GROUPS} /> );
    await userEvent.click( screen.getByRole( "combobox" ) );
    expect( await axe( container ) ).toHaveNoViolations( );
  } );
} );

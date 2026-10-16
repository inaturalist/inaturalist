import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import TabDrawer, { TabItem } from "./tab_drawer";

const items: TabItem[] = [
  { kind: "tab", value: "map", label: "Map" },
  { kind: "separator", value: "sep-1" },
  { kind: "tab", value: "about", label: "About" },
  {
    kind: "link", value: "help", label: "Help", href: "/help"
  },
  {
    kind: "action", value: "flag", label: "Flag", onClick: jest.fn( )
  }
];

describe( "TabDrawer", ( ) => {
  it( "shows the selected item's label on the toggle", ( ) => {
    render( <TabDrawer selectedValue="map" items={items} /> );
    expect( screen.getByRole( "button", { name: /Map/ } ) ).toHaveAttribute( "aria-expanded", "false" );
  } );

  it( "omits the current selection from the drawer but keeps the others", ( ) => {
    render( <TabDrawer selectedValue="map" items={items} /> );
    // "Map" only appears on the toggle, not as a drawer choice
    expect( screen.getAllByText( "Map" ) ).toHaveLength( 1 );
    expect( screen.getByText( "About" ) ).toBeInTheDocument( );
    expect( screen.getByText( "Help" ) ).toBeInTheDocument( );
  } );

  it( "renders a link item as an anchor", ( ) => {
    render( <TabDrawer selectedValue="map" items={items} /> );
    expect( screen.getByText( "Help" ).closest( "a" ) ).toHaveAttribute( "href", "/help" );
  } );

  it( "calls onChange with the value when a tab is chosen", async ( ) => {
    const onChange = jest.fn( );
    render( <TabDrawer selectedValue="map" items={items} onChange={onChange} /> );
    await userEvent.click( screen.getByText( "About" ) );
    expect( onChange ).toHaveBeenCalledWith( "about" );
  } );

  it( "calls an action item's onClick", async ( ) => {
    const onClick = jest.fn( );
    const withAction: TabItem[] = [
      { kind: "tab", value: "map", label: "Map" },
      {
        kind: "action", value: "flag", label: "Flag", onClick
      }
    ];
    render( <TabDrawer selectedValue="map" items={withAction} /> );
    await userEvent.click( screen.getByText( "Flag" ) );
    expect( onClick ).toHaveBeenCalledTimes( 1 );
  } );

  it( "toggles open state when the toggle is clicked", async ( ) => {
    render( <TabDrawer selectedValue="map" items={items} /> );
    const toggle = screen.getByRole( "button", { name: /Map/ } );
    expect( toggle ).toHaveAttribute( "aria-expanded", "false" );
    await userEvent.click( toggle );
    expect( toggle ).toHaveAttribute( "aria-expanded", "true" );
  } );
} );

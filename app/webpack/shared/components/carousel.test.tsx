import React from "react";
import { render, screen } from "@testing-library/react";
import Carousel from "./carousel";

// NOTE: jsdom has no layout, so the carousel's measurement-driven behavior
// (visibleCount from getBoundingClientRect, scroll-driven activeIndex,
// virtualization) is NOT covered here — that belongs in Playwright. These are
// render/prop smoke tests only.

const items = ["A", "B", "C"].map( label => <div key={label}>{ `Item ${label}` }</div> );

describe( "Carousel", ( ) => {
  it( "renders title and description", ( ) => {
    render( <Carousel items={items} title="Featured Species" description="Seen near you" /> );
    expect( screen.getByText( "Featured Species" ) ).toBeInTheDocument( );
    expect( screen.getByText( "Seen near you" ) ).toBeInTheDocument( );
  } );

  it( "renders the near-active items", ( ) => {
    render( <Carousel items={items} /> );
    expect( screen.getByText( "Item A" ) ).toBeInTheDocument( );
    expect( screen.getByText( "Item B" ) ).toBeInTheDocument( );
    expect( screen.getByText( "Item C" ) ).toBeInTheDocument( );
  } );

  it( "shows the empty state and no nav buttons when there are no items", ( ) => {
    render( <Carousel items={[]} noContent="Nothing here" /> );
    expect( screen.getByText( "Nothing here" ) ).toBeInTheDocument( );
    expect( screen.queryByTitle( "previous_taxon_short" ) ).not.toBeInTheDocument( );
  } );

  it( "disables prev at the start and enables next when there is more than one item", ( ) => {
    render( <Carousel items={items} /> );
    expect( screen.getByTitle( "previous_taxon_short" ) ).toBeDisabled( );
    expect( screen.getByTitle( "next_taxon_short" ) ).toBeEnabled( );
  } );

  it( "renders a view-all link when url is provided", ( ) => {
    render( <Carousel items={items} title="Featured" url="/taxa" /> );
    expect( screen.getByText( "view_all_caps" ).closest( "a" ) ).toHaveAttribute( "href", "/taxa" );
  } );
} );

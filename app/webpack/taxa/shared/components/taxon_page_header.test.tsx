import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import TaxonPageHeader from "./taxon_page_header";
import type { Taxon } from "../../../shared/types";

// TaxonAutocomplete is browser-heavy (jQuery widget); stub it down to a button
// that fires afterSelect so we can test the callback wiring.
jest.mock( "../../../shared/components/taxon_autocomplete", ( ) => ( {
  __esModule: true,
  default: ( { afterSelect }: { afterSelect: ( r: { item: unknown } ) => void } ) => (
    <button type="button" data-testid="autocomplete" onClick={( ) => afterSelect( { item: { id: 99 } } )}>
      search
    </button>
  )
} ) );
// TaxonCrumbsContainer is Redux-connected; stub it to surface the props the
// header forwards (currentText, showNewTaxon).
interface CrumbsMockProps {
  currentText?: string;
  showNewTaxon?: ( t: unknown ) => void;
}
jest.mock( "../containers/taxon_crumbs_container", ( ) => ( {
  __esModule: true,
  default: ( { currentText, showNewTaxon }: CrumbsMockProps ) => (
    <div data-testid="crumbs">
      { currentText }
      <button type="button" data-testid="new-taxon" onClick={( ) => showNewTaxon?.( { id: 7 } )}>
        new
      </button>
    </div>
  )
} ) );
// urlForTaxon transitively loads browser-only deps; stub with a simple builder.
jest.mock( "../util", ( ) => ( {
  urlForTaxon: ( t: { id: number } | null ) => ( t ? `/taxa/${t.id}` : null )
} ) );

const taxon: Taxon = { id: 5, name: "Panthera leo" };

describe( "TaxonPageHeader", ( ) => {
  it( "links the permalink to the taxon url", ( ) => {
    render(
      <TaxonPageHeader taxon={taxon} heading={<h1>Lion</h1>} afterSelect={jest.fn( )} />
    );
    expect( screen.getByLabelText( "permalink" ) ).toHaveAttribute( "href", "/taxa/5" );
  } );

  it( "renders the heading slot", ( ) => {
    render(
      <TaxonPageHeader taxon={taxon} heading={<h1>Lion</h1>} afterSelect={jest.fn( )} />
    );
    expect( screen.getByText( "Lion" ) ).toBeInTheDocument( );
  } );

  it( "renders the prefix and extra slots", ( ) => {
    render(
      <TaxonPageHeader
        taxon={taxon}
        heading={<h1>Lion</h1>}
        afterSelect={jest.fn( )}
        prefix={<div>before</div>}
        extra={<div>after</div>}
      />
    );
    expect( screen.getByText( "before" ) ).toBeInTheDocument( );
    expect( screen.getByText( "after" ) ).toBeInTheDocument( );
  } );

  it( "renders the placeChooser inside the place-chooser container", ( ) => {
    const { container } = render(
      <TaxonPageHeader
        taxon={taxon}
        heading={<h1>Lion</h1>}
        afterSelect={jest.fn( )}
        placeChooser={<span>chooser</span>}
      />
    );
    expect(
      container.querySelector( "#place-chooser-container" )
    ).toHaveTextContent( "chooser" );
  } );

  it( "forwards crumbsText to the crumbs container", ( ) => {
    render(
      <TaxonPageHeader
        taxon={taxon}
        heading={<h1>Lion</h1>}
        afterSelect={jest.fn( )}
        crumbsText="Felidae"
      />
    );
    expect( screen.getByTestId( "crumbs" ) ).toHaveTextContent( "Felidae" );
  } );

  it( "calls afterSelect when the autocomplete selects a taxon", async ( ) => {
    const afterSelect = jest.fn( );
    render(
      <TaxonPageHeader taxon={taxon} heading={<h1>Lion</h1>} afterSelect={afterSelect} />
    );
    await userEvent.click( screen.getByTestId( "autocomplete" ) );
    expect( afterSelect ).toHaveBeenCalledWith( { item: { id: 99 } } );
  } );

  it( "forwards showNewTaxon to the crumbs container", async ( ) => {
    const showNewTaxon = jest.fn( );
    render(
      <TaxonPageHeader
        taxon={taxon}
        heading={<h1>Lion</h1>}
        afterSelect={jest.fn( )}
        showNewTaxon={showNewTaxon}
      />
    );
    await userEvent.click( screen.getByTestId( "new-taxon" ) );
    expect( showNewTaxon ).toHaveBeenCalledWith( { id: 7 } );
  } );
} );

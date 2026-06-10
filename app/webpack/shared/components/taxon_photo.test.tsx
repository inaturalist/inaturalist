import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import TaxonPhoto from "./taxon_photo";
import type { Photo, Taxon, Observation } from "../types";

// Inert stubs so we test TaxonPhoto's own logic, not its children.
jest.mock( "./cover_image", ( ) => ( {
  __esModule: true,
  default: ( { src }: { src?: string } ) => <div data-testid="cover" data-src={src} />
} ) );
jest.mock( "./split_taxon", ( ) => ( {
  __esModule: true,
  default: ( props: { taxon?: { name?: string }; onClick?: ( e: React.MouseEvent ) => void } ) => (
    <button type="button" data-testid="split-taxon" onClick={props.onClick}>
      { props.taxon?.name }
    </button>
  )
} ) );

const photo = {
  id: 1,
  photoUrl: ( ) => "https://example.com/medium.jpg",
  dimensions: ( ) => ( { width: 400, height: 300 } )
} as unknown as Photo;
const taxon: Taxon = { id: 5, name: "Panthera leo" };
const observation = { id: 99 } as unknown as Observation;

describe( "TaxonPhoto", ( ) => {
  it( "opens the photo modal with photo, taxon, and observation", async ( ) => {
    const showTaxonPhotoModal = jest.fn( );
    render(
      <TaxonPhoto
        photo={photo}
        taxon={taxon}
        observation={observation}
        showTaxonPhotoModal={showTaxonPhotoModal}
      />
    );
    await userEvent.click( screen.getByRole( "button", { name: "view_photo" } ) );
    expect( showTaxonPhotoModal ).toHaveBeenCalledWith( photo, taxon, observation );
  } );

  it( "hides the taxon label unless showTaxon is set", ( ) => {
    const { rerender } = render(
      <TaxonPhoto photo={photo} taxon={taxon} showTaxonPhotoModal={jest.fn( )} />
    );
    expect( screen.queryByTestId( "split-taxon" ) ).not.toBeInTheDocument( );

    rerender(
      <TaxonPhoto photo={photo} taxon={taxon} showTaxon showTaxonPhotoModal={jest.fn( )} />
    );
    expect( screen.getByTestId( "split-taxon" ) ).toBeInTheDocument( );
  } );

  it( "renders the info link when linkTaxon is set", ( ) => {
    render(
      <TaxonPhoto
        photo={photo}
        taxon={taxon}
        showTaxon
        linkTaxon
        showTaxonPhotoModal={jest.fn( )}
      />
    );
    expect( screen.getByRole( "link", { name: "view_taxon" } ) )
      .toHaveAttribute( "href", "/taxa/5-Panthera-leo" );
  } );

  it( "calls onClickTaxon on a plain click but defers to the browser on modifier-click", ( ) => {
    const onClickTaxon = jest.fn( );
    render(
      <TaxonPhoto
        photo={photo}
        taxon={taxon}
        showTaxon
        linkTaxon
        onClickTaxon={onClickTaxon}
        showTaxonPhotoModal={jest.fn( )}
      />
    );
    const taxonLink = screen.getByTestId( "split-taxon" );

    fireEvent.click( taxonLink, { metaKey: true } );
    expect( onClickTaxon ).not.toHaveBeenCalled( );

    fireEvent.click( taxonLink );
    expect( onClickTaxon ).toHaveBeenCalledWith( taxon );
  } );
} );

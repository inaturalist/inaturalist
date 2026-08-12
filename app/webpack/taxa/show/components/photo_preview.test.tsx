import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import PhotoPreview from "./photo_preview";
import type { Photo, Taxon } from "../../../shared/types";

// Not under test, and its import chain reaches ESM-only deps jest does not transform.
jest.mock( "./photo_preview_legacy", ( ) => ( {
  __esModule: true,
  default: ( ) => <div data-testid="legacy-photo-preview" />
} ) );
jest.mock( "../../../shared/components/taxon_photo", ( ) => ( {
  __esModule: true,
  default: ( { photo }: { photo: { id: number } } ) => (
    <div data-testid="main-photo">{ `photo-${photo.id}` }</div>
  )
} ) );
jest.mock( "../../../shared/components/cover_image", ( ) => ( {
  __esModule: true,
  default: ( ) => <span />
} ) );
jest.mock( "../../shared/util", ( ) => ( {
  urlForTaxonPhotos: ( t: { id: number } ) => `/taxa/${t.id}/photos`
} ) );

const photo = ( id: number ) => ( {
  id,
  photoUrl: ( ) => `photo-${id}.jpg`,
  dimensions: ( ) => ( { width: 100, height: 100 } )
} ) as unknown as Photo;

const entries = ( taxonId: number, photoIds: number[] ) => photoIds.map( id => ( {
  taxon: { id: taxonId } as unknown as Taxon,
  photo: photo( id )
} ) );

describe( "PhotoPreview gallery", ( ) => {
  it( "switches the main photo when a thumbnail is clicked", ( ) => {
    render(
      <PhotoPreview
        taxon={{ id: 1 } as unknown as Taxon}
        taxonPhotos={entries( 1, [11, 12, 13] )}
        layout="gallery"
      />
    );
    expect( screen.getByTestId( "main-photo" ) ).toHaveTextContent( "photo-11" );
    fireEvent.click( screen.getAllByLabelText( "view_full_size_photo" )[2] );
    expect( screen.getByTestId( "main-photo" ) ).toHaveTextContent( "photo-13" );
  } );

  it( "resets to the new taxon's first photo when the taxon changes", ( ) => {
    const { rerender } = render(
      <PhotoPreview
        taxon={{ id: 1 } as unknown as Taxon}
        taxonPhotos={entries( 1, [11, 12, 13] )}
        layout="gallery"
      />
    );
    fireEvent.click( screen.getAllByLabelText( "view_full_size_photo" )[2] );
    expect( screen.getByTestId( "main-photo" ) ).toHaveTextContent( "photo-13" );

    rerender(
      <PhotoPreview
        taxon={{ id: 2 } as unknown as Taxon}
        taxonPhotos={entries( 2, [21] )}
        layout="gallery"
      />
    );
    expect( screen.getByTestId( "main-photo" ) ).toHaveTextContent( "photo-21" );
  } );
} );

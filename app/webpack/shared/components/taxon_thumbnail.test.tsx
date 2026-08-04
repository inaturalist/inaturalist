import React from "react";
import { render, screen } from "@testing-library/react";
import TaxonThumbnail from "./taxon_thumbnail";
import type { Photo, Taxon } from "../types";

// taxon_thumbnail imports urlForTaxon from taxa/shared/util, which transitively
// loads browser-only deps (heic-to). Stub it with a simple slug builder.
jest.mock( "../../taxa/shared/util", ( ) => ( {
  urlForTaxon: ( t: { id: number } | null ) => ( t ? `/taxa/${t.id}` : null )
} ) );
jest.mock( "./cover_image", ( ) => ( {
  __esModule: true,
  default: ( { src }: { src?: string } ) => <div data-testid="cover" data-src={src} />
} ) );
jest.mock( "./split_taxon", ( ) => ( {
  __esModule: true,
  default: ( { taxon }: { taxon?: { name?: string } } ) => <span>{ taxon?.name }</span>
} ) );

describe( "TaxonThumbnail photo source", ( ) => {
  it( "uses default_photo.medium_url from a raw API payload", ( ) => {
    const taxon: Taxon = {
      id: 1, name: "X", default_photo: { medium_url: "m.jpg", square_url: "s.jpg" }
    };
    render( <TaxonThumbnail taxon={taxon} /> );
    expect( screen.getByTestId( "cover" ) ).toHaveAttribute( "data-src", "m.jpg" );
  } );

  it( "uses defaultPhoto.photoUrl( 'medium' ) from a model instance", ( ) => {
    const defaultPhoto = {
      id: 9,
      photoUrl: ( size?: string ) => ( size === "medium" ? "med.jpg" : "sq.jpg" ),
      dimensions: ( ) => ( { width: 1, height: 1 } )
    } as Photo;
    render( <TaxonThumbnail taxon={{ id: 1, name: "X", defaultPhoto }} /> );
    expect( screen.getByTestId( "cover" ) ).toHaveAttribute( "data-src", "med.jpg" );
  } );

  it( "uses the photo prop over the taxon's default photo when both are present", ( ) => {
    const photo = {
      id: 7,
      photoUrl: ( size?: string ) => ( size === "medium" ? "prop-med.jpg" : "prop-sq.jpg" ),
      dimensions: ( ) => ( { width: 1, height: 1 } )
    } as Photo;
    const defaultPhoto = {
      id: 9,
      photoUrl: ( size?: string ) => ( size === "medium" ? "default-med.jpg" : "default-sq.jpg" ),
      dimensions: ( ) => ( { width: 1, height: 1 } )
    } as Photo;
    render( <TaxonThumbnail taxon={{ id: 1, name: "X", defaultPhoto }} photo={photo} /> );
    expect( screen.getByTestId( "cover" ) ).toHaveAttribute( "data-src", "prop-med.jpg" );
  } );

  it( "falls back to the iconic-taxon icon when there is no photo", ( ) => {
    const { container } = render(
      <TaxonThumbnail taxon={{ id: 1, name: "X", iconic_taxon_name: "Aves" }} />
    );
    expect( screen.queryByTestId( "cover" ) ).not.toBeInTheDocument( );
    expect( container.querySelector( ".icon-iconic-aves" ) ).toBeTruthy( );
  } );

  it( "suppresses the taxon's default photo when photo is explicitly null", ( ) => {
    const defaultPhoto = {
      id: 9,
      photoUrl: ( size?: string ) => ( size === "medium" ? "default-med.jpg" : "default-sq.jpg" ),
      dimensions: ( ) => ( { width: 1, height: 1 } )
    } as Photo;
    const taxon = {
      id: 1, name: "X", iconic_taxon_name: "Aves", defaultPhoto
    };
    const { container } = render(
      <TaxonThumbnail taxon={taxon} photo={null} />
    );
    expect( screen.queryByTestId( "cover" ) ).not.toBeInTheDocument( );
    expect( container.querySelector( ".icon-iconic-aves" ) ).toBeTruthy( );
  } );

  it( "uses the unknown icon when no iconic taxon is set", ( ) => {
    const { container } = render( <TaxonThumbnail taxon={{ id: 1, name: "X" }} /> );
    expect( container.querySelector( ".icon-iconic-unknown" ) ).toBeTruthy( );
  } );
} );

describe( "TaxonThumbnail optional slots", ( ) => {
  const taxon: Taxon = { id: 1, name: "X", iconic_taxon_name: "Aves" };

  it( "renders a caption from captionForTaxon", ( ) => {
    render(
      <TaxonThumbnail taxon={taxon} captionForTaxon={t => <em>{ `rank-${t.rank ?? "none"}` }</em>} />
    );
    expect( screen.getByText( "rank-none" ) ).toBeInTheDocument( );
  } );

  it( "renders a badge with an optional link", ( ) => {
    render( <TaxonThumbnail taxon={taxon} badge={{ text: "New", linkUrl: "/new" }} /> );
    expect( screen.getByText( "New" ).closest( "a" ) ).toHaveAttribute( "href", "/new" );
  } );
} );

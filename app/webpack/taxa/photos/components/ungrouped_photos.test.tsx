import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import UngroupedPhotos from "./ungrouped_photos";

// --- Mocks --------------------------------------------------------------

// jsdom can't scroll, so render the children directly and expose hasMore plus a
// button that triggers loadMore.
jest.mock( "react-infinite-scroller", ( ) => ( {
  __esModule: true,
  default: ( props: {
    hasMore?: boolean;
    loadMore: ( ) => void;
    className?: string;
    children?: React.ReactNode;
  } ) => (
    <div data-testid="infinite-scroll" data-has-more={String( props.hasMore )} className={props.className}>
      <button type="button" data-testid="load-more" onClick={props.loadMore}>more</button>
      { props.children }
    </div>
  )
} ) );

// The photo list is covered by observation_photos.test; here we only care that
// UngroupedPhotos hands it the right photos and layout.
jest.mock( "./observation_photos", ( ) => ( {
  __esModule: true,
  default: ( props: { observationPhotos?: unknown[]; layout?: string } ) => (
    <div
      data-testid="observation-photos"
      data-count={( props.observationPhotos || [] ).length}
      data-layout={props.layout}
    />
  )
} ) );

// --- Fixtures -----------------------------------------------------------

type Props = React.ComponentProps<typeof UngroupedPhotos>;
type ObsPhoto = NonNullable<Props["observationPhotos"]>[number];

const makeObsPhoto = ( id: number ): ObsPhoto => ( {
  photo: { id, photoUrl: ( ) => "", dimensions: ( ) => null },
  observation: { id: id * 100, taxon: { id: id * 10, name: `taxon-${id}` } }
} as unknown as ObsPhoto );

const renderUngrouped = ( overrides: Partial<Props> = {} ) => render(
  <UngroupedPhotos
    layout="fluid"
    loadMorePhotos={jest.fn( )}
    showTaxonPhotoModal={jest.fn( )}
    {...overrides}
  />
);

// --- Tests --------------------------------------------------------------

describe( "UngroupedPhotos", ( ) => {
  it( "renders InfiniteScroll with hasMore and triggers loadMorePhotos", ( ) => {
    const loadMorePhotos = jest.fn( );
    renderUngrouped( {
      observationPhotos: [makeObsPhoto( 1 )], hasMorePhotos: true, loadMorePhotos
    } );
    expect( screen.getByTestId( "infinite-scroll" ) ).toHaveAttribute( "data-has-more", "true" );
    fireEvent.click( screen.getByTestId( "load-more" ) );
    expect( loadMorePhotos ).toHaveBeenCalled( );
  } );

  it( "passes its photos and layout through to ObservationPhotos", ( ) => {
    renderUngrouped( {
      observationPhotos: [makeObsPhoto( 1 ), makeObsPhoto( 2 )], layout: "grid"
    } );
    const photos = screen.getByTestId( "observation-photos" );
    expect( photos ).toHaveAttribute( "data-count", "2" );
    expect( photos ).toHaveAttribute( "data-layout", "grid" );
  } );

  it( "shows the no-observations notice for an empty result", ( ) => {
    renderUngrouped( { observationPhotos: [] } );
    expect( screen.getByText( "no_observations_yet" ) ).toBeInTheDocument( );
  } );

  it( "shows the place-specific notice when a place is set", ( ) => {
    renderUngrouped( {
      observationPhotos: [],
      place: { id: 1, display_name: "California" }
    } );
    expect( screen.getByText( "no_observations_from_this_place_yet" ) ).toBeInTheDocument( );
  } );

  it( "shows the loader (and no notice) while observationPhotos is undefined", ( ) => {
    const { container } = renderUngrouped( { observationPhotos: undefined } );
    expect( container.querySelector( ".loading" ) ).toBeInTheDocument( );
    expect( screen.queryByText( "no_observations_yet" ) ).not.toBeInTheDocument( );
  } );
} );

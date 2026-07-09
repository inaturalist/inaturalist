import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import ObservationPhotos from "./observation_photos";

// --- Mocks --------------------------------------------------------------

// Capture the props ObservationPhotos passes to each TaxonPhoto (layout-dependent
// dimensions, square flag) and expose the modal callback as a clickable button.
jest.mock( "../../../shared/components/taxon_photo", ( ) => ( {
  __esModule: true,
  default: ( props: {
    photo?: { id?: number };
    width?: number;
    height?: number;
    square?: boolean;
    showTaxonPhotoModal: ( ) => void;
  } ) => (
    <div
      data-testid="taxon-photo"
      data-photo-id={props.photo?.id}
      data-width={props.width}
      data-height={props.height}
      data-square={String( props.square )}
    >
      <button type="button" data-testid="open-modal" onClick={props.showTaxonPhotoModal}>
        open
      </button>
    </div>
  )
} ) );

// --- Fixtures -----------------------------------------------------------

type Props = React.ComponentProps<typeof ObservationPhotos>;
type ObsPhoto = NonNullable<Props["observationPhotos"]>[number];

const makeObsPhoto = (
  id: number,
  dims: { width: number; height: number } | null
): ObsPhoto => ( {
  photo: {
    id,
    photoUrl: ( ) => "",
    dimensions: ( ) => dims
  },
  observation: {
    id: id * 100,
    taxon: { id: id * 10, name: `taxon-${id}` }
  }
} as unknown as ObsPhoto );

const renderPhotos = ( overrides: Partial<Props> = {} ) => render(
  <ObservationPhotos
    layout="fluid"
    showTaxonPhotoModal={jest.fn( )}
    {...overrides}
  />
);

// --- Tests --------------------------------------------------------------

describe( "ObservationPhotos", ( ) => {
  it( "renders one TaxonPhoto per observation photo", ( ) => {
    renderPhotos( { observationPhotos: [makeObsPhoto( 1, null ), makeObsPhoto( 2, null )] } );
    expect( screen.getAllByTestId( "taxon-photo" ) ).toHaveLength( 2 );
  } );

  it( "renders nothing when there are no photos", ( ) => {
    renderPhotos( { observationPhotos: [] } );
    expect( screen.queryByTestId( "taxon-photo" ) ).not.toBeInTheDocument( );
  } );

  it( "opens the modal with the photo, taxon, and observation", ( ) => {
    const showTaxonPhotoModal = jest.fn( );
    const op = makeObsPhoto( 1, null );
    renderPhotos( { observationPhotos: [op], showTaxonPhotoModal } );
    fireEvent.click( screen.getByTestId( "open-modal" ) );
    const { photo, observation } = op;
    expect( showTaxonPhotoModal ).toHaveBeenCalledWith( photo, observation.taxon, observation );
  } );

  it( "passes fluid dimensions (height 233, width scaled from photo dims, square=false)", ( ) => {
    renderPhotos( { layout: "fluid", observationPhotos: [makeObsPhoto( 1, { width: 200, height: 100 } )] } );
    const photo = screen.getByTestId( "taxon-photo" );
    expect( photo ).toHaveAttribute( "data-height", "233" );
    expect( photo ).toHaveAttribute( "data-width", "466" ); // 233 / 100 * 200
    expect( photo ).toHaveAttribute( "data-square", "false" );
  } );

  it( "falls back to width 233 in fluid layout when the photo has no dimensions", ( ) => {
    renderPhotos( { layout: "fluid", observationPhotos: [makeObsPhoto( 1, null )] } );
    expect( screen.getByTestId( "taxon-photo" ) ).toHaveAttribute( "data-width", "233" );
  } );

  it( "passes square=true and no width/height in grid layout", ( ) => {
    renderPhotos( { layout: "grid", observationPhotos: [makeObsPhoto( 1, { width: 200, height: 100 } )] } );
    const photo = screen.getByTestId( "taxon-photo" );
    expect( photo ).toHaveAttribute( "data-square", "true" );
    expect( photo ).not.toHaveAttribute( "data-width" );
    expect( photo ).not.toHaveAttribute( "data-height" );
  } );
} );

import React from "react";
import { render, screen } from "@testing-library/react";
import GroupedPhotos from "./grouped_photos";

// --- Mocks --------------------------------------------------------------

// urlForTaxonPhotos transitively loads browser-only deps; stub it so the
// group-title url assertions stay meaningful.
jest.mock( "../../shared/util", ( ) => ( {
  urlForTaxonPhotos: ( t: { id?: number } ) => `/taxa/${t?.id}/browse_photos`
} ) );

// controlledTermLabel lives in shared/util, which pulls in browser-only deps
// (heic-to etc.); stub it to the translation key the real helper produces under
// the I18n test stub.
jest.mock( "../../../shared/util", ( ) => {
  // eslint-disable-next-line global-require, @typescript-eslint/no-var-requires
  const snakeCase = require( "lodash/snakeCase" );
  return {
    __esModule: true,
    controlledTermLabel: ( label: string ) => `controlled_term_labels.${snakeCase( label )}`
  };
} );

jest.mock( "../../../shared/components/split_taxon", ( ) => ( {
  __esModule: true,
  default: ( props: { taxon?: { id?: number }; url?: string } ) => (
    <span data-testid="split-taxon" data-taxon-id={props.taxon?.id} data-url={props.url} />
  )
} ) );

// The photo list is covered by observation_photos.test; here we only care about
// the group structure, titles, links, and how many photos each group receives.
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

type Props = React.ComponentProps<typeof GroupedPhotos>;
type Group = Props["groupedPhotos"][string];
type ObsPhoto = Group["observationPhotos"][number];

const makeObsPhoto = ( id: number ): ObsPhoto => ( {
  photo: { id, photoUrl: ( ) => "", dimensions: ( ) => null },
  observation: { id: id * 100, taxon: { id: id * 10, name: `taxon-${id}` } }
} as unknown as ObsPhoto );

const makeGroup = (
  groupName: string,
  groupObject: Record<string, unknown>,
  observationPhotos: ObsPhoto[]
): Group => ( { groupName, groupObject, observationPhotos } as unknown as Group );

const baseProps: Props = {
  groupedPhotos: {},
  grouping: {},
  params: {},
  layout: "fluid",
  showTaxonPhotoModal: jest.fn( )
};

const renderGrouped = ( overrides: Partial<Props> = {} ) => render(
  <GroupedPhotos {...baseProps} {...overrides} />
);

beforeEach( ( ) => {
  ( global as unknown as Record<string, unknown> ).$ = {
    param: ( obj: Record<string, unknown> ) => Object.entries( obj )
      .map( ( [k, v] ) => `${k}=${v}` ).join( "&" ),
    deparam: ( ) => ( {} )
  };
} );

afterEach( ( ) => {
  // Real global, not a jest mock, so clearMocks won't reset it; remove it so it
  // can't leak into other test files in the same worker.
  delete ( global as unknown as Record<string, unknown> ).$;
} );

// --- Tests --------------------------------------------------------------

describe( "GroupedPhotos", ( ) => {
  it( "hands each group's photos to ObservationPhotos", ( ) => {
    renderGrouped( {
      grouping: { param: "field:foo" },
      groupedPhotos: {
        g: makeGroup( "Adult", { id: 9 }, [makeObsPhoto( 1 ), makeObsPhoto( 2 )] )
      }
    } );
    expect( screen.getByTestId( "observation-photos" ) ).toHaveAttribute( "data-count", "2" );
  } );

  it( "renders a group per entry and marks the first one", ( ) => {
    const { container } = renderGrouped( {
      grouping: { param: "field:foo" },
      groupedPhotos: {
        b: makeGroup( "Banana", {}, [makeObsPhoto( 1 )] ),
        a: makeGroup( "Apple", {}, [makeObsPhoto( 2 )] )
      }
    } );
    const groups = container.querySelectorAll( ".photo-group" );
    expect( groups ).toHaveLength( 2 );
    expect( groups[0] ).toHaveClass( "first" );
    expect( groups[1] ).not.toHaveClass( "first" );
  } );

  it( "sorts taxon_id groups by groupObject.name", ( ) => {
    renderGrouped( {
      grouping: { param: "taxon_id" },
      groupedPhotos: {
        z: makeGroup( "z", { id: 1, name: "Zebra" }, [makeObsPhoto( 1 )] ),
        a: makeGroup( "a", { id: 2, name: "Antelope" }, [makeObsPhoto( 2 )] )
      }
    } );
    const ids = screen.getAllByTestId( "split-taxon" ).map( el => el.getAttribute( "data-taxon-id" ) );
    expect( ids ).toEqual( ["2", "1"] );
  } );

  it( "sorts non-taxon groups by groupName", ( ) => {
    renderGrouped( {
      grouping: { param: "field:foo" },
      groupedPhotos: {
        b: makeGroup( "Banana", {}, [makeObsPhoto( 1 )] ),
        a: makeGroup( "Apple", {}, [makeObsPhoto( 2 )] )
      }
    } );
    const headings = screen.getAllByRole( "heading", { level: 3 } ).map( h => h.textContent );
    expect( headings ).toEqual( ["controlled_term_labels.apple", "controlled_term_labels.banana"] );
  } );

  it( "renders a SplitTaxon title with the photos url for taxon_id grouping", ( ) => {
    renderGrouped( {
      grouping: { param: "taxon_id" },
      groupedPhotos: { g: makeGroup( "g", { id: 42, name: "Foo" }, [makeObsPhoto( 1 )] ) }
    } );
    const splitTaxon = screen.getByTestId( "split-taxon" );
    expect( splitTaxon ).toHaveAttribute( "data-taxon-id", "42" );
    expect( splitTaxon ).toHaveAttribute( "data-url", "/taxa/42/browse_photos" );
  } );

  it( "shows the per-group empty notice when a group has no photos", ( ) => {
    renderGrouped( {
      grouping: { param: "field:foo" },
      groupedPhotos: { g: makeGroup( "Empty", {}, [] ) }
    } );
    expect( screen.getByText( "no_observations_yet" ) ).toBeInTheDocument( );
    expect( screen.getByTestId( "observation-photos" ) ).toHaveAttribute( "data-count", "0" );
  } );

  it( "builds a taxon_id observations link", ( ) => {
    renderGrouped( {
      grouping: { param: "taxon_id" },
      groupedPhotos: { g: makeGroup( "g", { id: 5, name: "Foo" }, [makeObsPhoto( 1 )] ) }
    } );
    expect( screen.getByRole( "link", { name: "view_observations" } ) )
      .toHaveAttribute( "href", "/observations?taxon_id=5" );
  } );

  it( "builds a terms observations link with term_id and term_value_id", ( ) => {
    renderGrouped( {
      grouping: { param: "terms:3", values: 3 },
      taxon: { id: 7, name: "Aves" },
      groupedPhotos: { g: makeGroup( "Adult", { id: 9 }, [makeObsPhoto( 1 )] ) }
    } );
    expect( screen.getByRole( "link", { name: "view_observations" } ) )
      .toHaveAttribute( "href", "/observations?taxon_id=7&term_id=3&term_value_id=9" );
  } );

  it( "omits the observations link when the group has no id", ( ) => {
    renderGrouped( {
      grouping: { param: "taxon_id" },
      groupedPhotos: { g: makeGroup( "g", { name: "NoId" }, [makeObsPhoto( 1 )] ) }
    } );
    expect( screen.queryByRole( "link", { name: "view_observations" } ) ).not.toBeInTheDocument( );
  } );
} );

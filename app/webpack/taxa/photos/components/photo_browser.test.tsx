import React from "react";
import {
  render, screen, fireEvent, within
} from "@testing-library/react";
import PhotoBrowser from "./photo_browser";

// --- Mocks --------------------------------------------------------------

// urlForTaxonPhotos transitively loads browser-only deps; stub it so the
// group-title url assertions stay meaningful.
jest.mock( "../../shared/util", ( ) => ( {
  urlForTaxonPhotos: ( t: { id?: number } ) => `/taxa/${t?.id}/browse_photos`
} ) );

// Capture the props PhotoBrowser passes to each TaxonPhoto (layout-dependent
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

jest.mock( "../../../shared/components/split_taxon", ( ) => ( {
  __esModule: true,
  default: ( props: { taxon?: { id?: number }; url?: string } ) => (
    <span data-testid="split-taxon" data-taxon-id={props.taxon?.id} data-url={props.url} />
  )
} ) );

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

// The real Dropdown only mounts its menu when open and wires onSelect via
// context. These stubs render every MenuItem as a button that calls the parent
// Dropdown's onSelect with its eventKey — letting us assert the exact callback
// arguments (incl. the non-string controlled_attribute eventKey).
jest.mock( "react-bootstrap", ( ) => {
  // eslint-disable-next-line global-require, @typescript-eslint/no-var-requires, no-shadow
  const React = require( "react" );
  const SelectContext = React.createContext( undefined );
  const Dropdown = Object.assign(
    ( props: { id?: string; onSelect?: ( key: unknown ) => void; children?: React.ReactNode } ) => (
      <div data-testid={`dropdown-${props.id}`}>
        <SelectContext.Provider value={props.onSelect}>
          { props.children }
        </SelectContext.Provider>
      </div>
    ),
    {
      Toggle: ( props: { children?: React.ReactNode } ) => (
        <div data-testid="dropdown-toggle">{ props.children }</div>
      ),
      Menu: ( props: { children?: React.ReactNode } ) => (
        <div data-testid="dropdown-menu">{ props.children }</div>
      )
    }
  );
  const MenuItem = ( props: {
    eventKey?: unknown; active?: boolean; children?: React.ReactNode;
  } ) => {
    const onSelect = React.useContext( SelectContext );
    return (
      <button
        type="button"
        role="menuitem"
        data-active={String( !!props.active )}
        onClick={( ) => { if ( onSelect ) { onSelect( props.eventKey ); } }}
      >
        { props.children }
      </button>
    );
  };
  const Button = ( props: {
    active?: boolean;
    title?: string;
    onClick?: ( ) => void;
    children?: React.ReactNode;
  } ) => (
    <button type="button" title={props.title} data-active={String( !!props.active )} onClick={props.onClick}>
      { props.children }
    </button>
  );
  const ButtonGroup = ( props: { id?: string; children?: React.ReactNode } ) => (
    <div id={props.id}>{ props.children }</div>
  );
  return {
    __esModule: true, Dropdown, MenuItem, Button, ButtonGroup
  };
} );

// --- Fixtures -----------------------------------------------------------

type Props = React.ComponentProps<typeof PhotoBrowser>;
type ObsPhoto = NonNullable<Props["observationPhotos"]>[number];
type Group = NonNullable<Props["groupedPhotos"]>[string];

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

const makeGroup = (
  groupName: string,
  groupObject: Record<string, unknown>,
  observationPhotos: ObsPhoto[]
): Group => ( { groupName, groupObject, observationPhotos } as unknown as Group );

const baseProps: Props = {
  loadMorePhotos: jest.fn( ),
  setLayout: jest.fn( ),
  showTaxonPhotoModal: jest.fn( )
};

const renderBrowser = ( overrides: Partial<Props> = {} ) => render(
  <PhotoBrowser {...baseProps} {...overrides} />
);

beforeEach( ( ) => {
  // photoLicenses reads iNaturalist.Licenses at render; only cc* keys survive.
  ( global as unknown as Record<string, unknown> ).iNaturalist = {
    Licenses: { cc_by: {}, cc_by_nc: {}, gfdl: {} }
  };
  ( global as unknown as Record<string, unknown> ).$ = {
    param: ( obj: Record<string, unknown> ) => Object.entries( obj )
      .map( ( [k, v] ) => `${k}=${v}` ).join( "&" ),
    deparam: ( ) => ( {} )
  };
} );

// --- Tests --------------------------------------------------------------

describe( "PhotoBrowser layout", ( ) => {
  it( "reflects the active layout on the root element and toggle buttons", ( ) => {
    const { container, rerender } = renderBrowser( { layout: "fluid" } );
    expect( container.querySelector( ".PhotoBrowser" ) ).toHaveClass( "fluid" );
    expect( screen.getByTitle( "fluid_layout" ) ).toHaveAttribute( "data-active", "true" );
    expect( screen.getByTitle( "grid_layout" ) ).toHaveAttribute( "data-active", "false" );

    rerender( <PhotoBrowser {...baseProps} layout="grid" /> );
    expect( container.querySelector( ".PhotoBrowser" ) ).toHaveClass( "grid" );
    expect( screen.getByTitle( "grid_layout" ) ).toHaveAttribute( "data-active", "true" );
  } );

  it( "calls setLayout when a layout button is clicked", ( ) => {
    const setLayout = jest.fn( );
    renderBrowser( { setLayout } );
    fireEvent.click( screen.getByTitle( "grid_layout" ) );
    expect( setLayout ).toHaveBeenCalledWith( "grid" );
    fireEvent.click( screen.getByTitle( "fluid_layout" ) );
    expect( setLayout ).toHaveBeenCalledWith( "fluid" );
  } );

  it( "passes fluid dimensions (height 233, width scaled from photo dims, square=false)", ( ) => {
    renderBrowser( { layout: "fluid", observationPhotos: [makeObsPhoto( 1, { width: 200, height: 100 } )] } );
    const photo = screen.getByTestId( "taxon-photo" );
    expect( photo ).toHaveAttribute( "data-height", "233" );
    expect( photo ).toHaveAttribute( "data-width", "466" ); // 233 / 100 * 200
    expect( photo ).toHaveAttribute( "data-square", "false" );
  } );

  it( "falls back to width 233 in fluid layout when the photo has no dimensions", ( ) => {
    renderBrowser( { layout: "fluid", observationPhotos: [makeObsPhoto( 1, null )] } );
    expect( screen.getByTestId( "taxon-photo" ) ).toHaveAttribute( "data-width", "233" );
  } );

  it( "passes square=true and no width/height in grid layout", ( ) => {
    renderBrowser( { layout: "grid", observationPhotos: [makeObsPhoto( 1, { width: 200, height: 100 } )] } );
    const photo = screen.getByTestId( "taxon-photo" );
    expect( photo ).toHaveAttribute( "data-square", "true" );
    expect( photo ).not.toHaveAttribute( "data-width" );
    expect( photo ).not.toHaveAttribute( "data-height" );
  } );
} );

describe( "PhotoBrowser ungrouped rendering", ( ) => {
  it( "renders one TaxonPhoto per observation photo", ( ) => {
    renderBrowser( { observationPhotos: [makeObsPhoto( 1, null ), makeObsPhoto( 2, null )] } );
    expect( screen.getAllByTestId( "taxon-photo" ) ).toHaveLength( 2 );
  } );

  it( "opens the modal with the photo, taxon, and observation", ( ) => {
    const showTaxonPhotoModal = jest.fn( );
    const op = makeObsPhoto( 1, null );
    renderBrowser( { observationPhotos: [op], showTaxonPhotoModal } );
    fireEvent.click( screen.getByTestId( "open-modal" ) );
    const { photo, observation } = op;
    expect( showTaxonPhotoModal ).toHaveBeenCalledWith( photo, observation.taxon, observation );
  } );

  it( "renders InfiniteScroll with hasMore and triggers loadMorePhotos", ( ) => {
    const loadMorePhotos = jest.fn( );
    renderBrowser( {
      observationPhotos: [makeObsPhoto( 1, null )], hasMorePhotos: true, loadMorePhotos
    } );
    expect( screen.getByTestId( "infinite-scroll" ) ).toHaveAttribute( "data-has-more", "true" );
    fireEvent.click( screen.getByTestId( "load-more" ) );
    expect( loadMorePhotos ).toHaveBeenCalled( );
  } );

  it( "shows the no-observations notice for an empty result", ( ) => {
    renderBrowser( { observationPhotos: [] } );
    expect( screen.getByText( "no_observations_yet" ) ).toBeInTheDocument( );
  } );

  it( "shows the place-specific notice when a place is set", ( ) => {
    renderBrowser( {
      observationPhotos: [],
      place: { id: 1, display_name: "California" }
    } );
    expect( screen.getByText( "no_observations_from_this_place_yet" ) ).toBeInTheDocument( );
  } );

  it( "shows the loader (and no notice) while observationPhotos is undefined", ( ) => {
    const { container } = renderBrowser( { observationPhotos: undefined } );
    expect( container.querySelector( ".loading" ) ).toBeInTheDocument( );
    expect( screen.queryByText( "no_observations_yet" ) ).not.toBeInTheDocument( );
  } );
} );

describe( "PhotoBrowser grouped rendering", ( ) => {
  it( "renders observation photos in a populated group", ( ) => {
    renderBrowser( {
      grouping: { param: "field:foo" },
      groupedPhotos: {
        g: makeGroup( "Adult", { id: 9 }, [makeObsPhoto( 1, null ), makeObsPhoto( 2, null )] )
      }
    } );
    expect( screen.getAllByTestId( "taxon-photo" ) ).toHaveLength( 2 );
  } );

  it( "renders photos after switching into a grouping (groups fill in asynchronously)", ( ) => {
    const grouping = { param: "field:foo" };
    const groupedPhotos: Record<string, Group> = {};

    // 1. No grouping selected yet — ungrouped view.
    const { rerender } = render(
      <PhotoBrowser {...baseProps} grouping={{}} groupedPhotos={{}} />
    );

    // 2. User switches to a grouping: the group exists but its photos haven't loaded.
    groupedPhotos.adult = makeGroup( "Adult", { id: 9 }, [] );
    rerender(
      <PhotoBrowser {...baseProps} grouping={grouping} groupedPhotos={groupedPhotos} />
    );
    expect( screen.queryByTestId( "taxon-photo" ) ).not.toBeInTheDocument( );

    // 3. Fetch resolves: photos are dropped into the same container, in place.
    const photos = [makeObsPhoto( 1, null ), makeObsPhoto( 2, null )];
    groupedPhotos.adult = makeGroup( "Adult", { id: 9 }, photos );
    rerender(
      <PhotoBrowser {...baseProps} grouping={grouping} groupedPhotos={groupedPhotos} />
    );
    expect( screen.getAllByTestId( "taxon-photo" ) ).toHaveLength( 2 );
  } );

  it( "renders a group per entry and marks the first one", ( ) => {
    const { container } = renderBrowser( {
      grouping: { param: "field:foo" },
      groupedPhotos: {
        b: makeGroup( "Banana", {}, [makeObsPhoto( 1, null )] ),
        a: makeGroup( "Apple", {}, [makeObsPhoto( 2, null )] )
      }
    } );
    const groups = container.querySelectorAll( ".photo-group" );
    expect( groups ).toHaveLength( 2 );
    expect( groups[0] ).toHaveClass( "first" );
    expect( groups[1] ).not.toHaveClass( "first" );
  } );

  it( "sorts taxon_id groups by groupObject.name", ( ) => {
    renderBrowser( {
      grouping: { param: "taxon_id" },
      groupedPhotos: {
        z: makeGroup( "z", { id: 1, name: "Zebra" }, [makeObsPhoto( 1, null )] ),
        a: makeGroup( "a", { id: 2, name: "Antelope" }, [makeObsPhoto( 2, null )] )
      }
    } );
    const ids = screen.getAllByTestId( "split-taxon" ).map( el => el.getAttribute( "data-taxon-id" ) );
    expect( ids ).toEqual( ["2", "1"] );
  } );

  it( "sorts non-taxon groups by groupName", ( ) => {
    renderBrowser( {
      grouping: { param: "field:foo" },
      groupedPhotos: {
        b: makeGroup( "Banana", {}, [makeObsPhoto( 1, null )] ),
        a: makeGroup( "Apple", {}, [makeObsPhoto( 2, null )] )
      }
    } );
    const headings = screen.getAllByRole( "heading", { level: 3 } ).map( h => h.textContent );
    expect( headings ).toEqual( ["controlled_term_labels.apple", "controlled_term_labels.banana"] );
  } );

  it( "renders a SplitTaxon title with the photos url for taxon_id grouping", ( ) => {
    renderBrowser( {
      grouping: { param: "taxon_id" },
      groupedPhotos: { g: makeGroup( "g", { id: 42, name: "Foo" }, [makeObsPhoto( 1, null )] ) }
    } );
    const splitTaxon = screen.getByTestId( "split-taxon" );
    expect( splitTaxon ).toHaveAttribute( "data-taxon-id", "42" );
    expect( splitTaxon ).toHaveAttribute( "data-url", "/taxa/42/browse_photos" );
  } );

  it( "shows the per-group empty notice when a group has no photos", ( ) => {
    renderBrowser( {
      grouping: { param: "field:foo" },
      groupedPhotos: { g: makeGroup( "Empty", {}, [] ) }
    } );
    expect( screen.getByText( "no_observations_yet" ) ).toBeInTheDocument( );
    expect( screen.queryByTestId( "taxon-photo" ) ).not.toBeInTheDocument( );
  } );

  it( "builds a taxon_id observations link", ( ) => {
    renderBrowser( {
      grouping: { param: "taxon_id" },
      groupedPhotos: { g: makeGroup( "g", { id: 5, name: "Foo" }, [makeObsPhoto( 1, null )] ) }
    } );
    expect( screen.getByRole( "link", { name: "view_observations" } ) )
      .toHaveAttribute( "href", "/observations?taxon_id=5" );
  } );

  it( "builds a terms observations link with term_id and term_value_id", ( ) => {
    renderBrowser( {
      grouping: { param: "terms:3", values: 3 },
      taxon: { id: 7, name: "Aves" },
      groupedPhotos: { g: makeGroup( "Adult", { id: 9 }, [makeObsPhoto( 1, null )] ) }
    } );
    expect( screen.getByRole( "link", { name: "view_observations" } ) )
      .toHaveAttribute( "href", "/observations?taxon_id=7&term_id=3&term_value_id=9" );
  } );

  it( "omits the observations link when the group has no id", ( ) => {
    renderBrowser( {
      grouping: { param: "taxon_id" },
      groupedPhotos: { g: makeGroup( "g", { name: "NoId" }, [makeObsPhoto( 1, null )] ) }
    } );
    expect( screen.queryByRole( "link", { name: "view_observations" } ) ).not.toBeInTheDocument( );
  } );
} );

describe( "PhotoBrowser grouping dropdown", ( ) => {
  const terms = {
    1: [{
      controlled_attribute: { id: 1, label: "Life Stage" },
      controlled_value: { id: 10, label: "Adult" }
    }]
  };

  it( "lists none / taxonomic / per-term items with correct active state", ( ) => {
    renderBrowser( { grouping: { param: "taxon_id" }, terms } );
    const menu = within( screen.getByTestId( "dropdown-grouping-control" ) );
    expect( menu.getByRole( "menuitem", { name: "none" } ) ).toHaveAttribute( "data-active", "false" );
    expect( menu.getByRole( "menuitem", { name: "taxonomic" } ) ).toHaveAttribute( "data-active", "true" );
    expect( menu.getByRole( "menuitem", { name: "controlled_term_labels.life_stage" } ) )
      .toBeInTheDocument( );
  } );

  it( "calls setGrouping(null) for none, ('taxon_id') for taxonomic, ('terms:<id>', id) for a term", ( ) => {
    const setGrouping = jest.fn( );
    renderBrowser( { terms, setGrouping } );
    const menu = within( screen.getByTestId( "dropdown-grouping-control" ) );

    fireEvent.click( menu.getByRole( "menuitem", { name: "none" } ) );
    expect( setGrouping ).toHaveBeenCalledWith( null );

    fireEvent.click( menu.getByRole( "menuitem", { name: "taxonomic" } ) );
    expect( setGrouping ).toHaveBeenCalledWith( "taxon_id" );

    fireEvent.click( menu.getByRole( "menuitem", { name: "controlled_term_labels.life_stage" } ) );
    expect( setGrouping ).toHaveBeenCalledWith( "terms:1", 1 );
  } );

  it( "hides the grouping dropdown when there is nothing to group by", ( ) => {
    renderBrowser( { showTaxonGrouping: false, terms: {} } );
    expect( screen.queryByTestId( "dropdown-grouping-control" ) ).not.toBeInTheDocument( );
  } );
} );

// TODO: when groups besides taxonomic are selected, terms and some other filtesr are unable to be
// applied but they potentially should be
describe( "PhotoBrowser term filter dropdown", ( ) => {
  const terms = {
    1: [{
      controlled_attribute: { id: 1, label: "Life Stage" },
      controlled_value: { id: 10, label: "Adult" }
    }]
  };

  it( "shows the selected value in the toggle and calls setTerm on selection", ( ) => {
    const setTerm = jest.fn( );
    renderBrowser( {
      terms,
      selectedTerm: { id: 1, label: "Life Stage" },
      selectedTermValue: { id: 10, label: "Adult" },
      setTerm
    } );
    const dropdown = within( screen.getByTestId( "dropdown-term-chooser-Life Stage" ) );
    expect( dropdown.getByTestId( "dropdown-toggle" ) )
      .toHaveTextContent( "controlled_term_labels.adult" );

    fireEvent.click( dropdown.getByRole( "menuitem", { name: "controlled_term_labels.adult" } ) );
    expect( setTerm ).toHaveBeenCalledWith( 1, 10 );
    fireEvent.click( dropdown.getByRole( "menuitem", { name: "controlled_term_labels.any_life_stage" } ) );
    expect( setTerm ).toHaveBeenCalledWith( 1, "any" );
  } );
} );

describe( "PhotoBrowser filter dropdowns", ( ) => {
  it( "renders order-by options and calls setParam", ( ) => {
    const setParam = jest.fn( );
    renderBrowser( { params: { order_by: "votes" }, setParam } );
    const dropdown = within( screen.getByTestId( "dropdown-sort-control" ) );
    // votes -> "faves", created_at -> "date_added"
    expect( dropdown.getByRole( "menuitem", { name: "faves" } ) ).toHaveAttribute( "data-active", "true" );
    expect( dropdown.getByRole( "menuitem", { name: "date_added" } ) ).toHaveAttribute( "data-active", "false" );
    fireEvent.click( dropdown.getByRole( "menuitem", { name: "date_added" } ) );
    expect( setParam ).toHaveBeenCalledWith( "order_by", "created_at" );
  } );

  it( "lists only cc* licenses and calls setParam", ( ) => {
    const setParam = jest.fn( );
    renderBrowser( { setParam } );
    const dropdown = within( screen.getByTestId( "dropdown-license-control" ) );
    expect( dropdown.getByRole( "menuitem", { name: "cc_by_name" } ) ).toBeInTheDocument( );
    expect( dropdown.getByRole( "menuitem", { name: "cc_by_nc_name" } ) ).toBeInTheDocument( );
    // gfdl is filtered out (does not start with "cc")
    expect( dropdown.queryByRole( "menuitem", { name: "gfdl_name" } ) ).not.toBeInTheDocument( );
    fireEvent.click( dropdown.getByRole( "menuitem", { name: "cc_by_name" } ) );
    expect( setParam ).toHaveBeenCalledWith( "photo_license", "cc_by" );
  } );

  it( "renders quality-grade options and calls setParam", ( ) => {
    const setParam = jest.fn( );
    renderBrowser( { params: { quality_grade: "research" }, setParam } );
    const dropdown = within( screen.getByTestId( "dropdown-quality-grade-control" ) );
    // research -> "research_", any -> "any_quality_grade"
    expect( dropdown.getByRole( "menuitem", { name: "research_" } ) ).toHaveAttribute( "data-active", "true" );
    expect( dropdown.getByRole( "menuitem", { name: "any_quality_grade" } ) )
      .toHaveAttribute( "data-active", "false" );
    fireEvent.click( dropdown.getByRole( "menuitem", { name: "any_quality_grade" } ) );
    expect( setParam ).toHaveBeenCalledWith( "quality_grade", "any" );
  } );
} );

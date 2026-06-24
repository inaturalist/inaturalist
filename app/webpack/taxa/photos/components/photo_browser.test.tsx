import React from "react";
import {
  render, screen, fireEvent, within
} from "@testing-library/react";
import PhotoBrowser from "./photo_browser";

// --- Mocks --------------------------------------------------------------
//
// PhotoBrowser is tested through its real child components (GroupedPhotos /
// UngroupedPhotos / ObservationPhotos) so the grouped-vs-ungrouped decision and
// the controls are exercised end to end. The leaf rendering of each child has
// its own test file; here we only stub the browser-only primitives.

// urlForTaxonPhotos transitively loads browser-only deps; stub it so the
// group-title url assertions stay meaningful.
jest.mock( "../../shared/util", ( ) => ( {
  urlForTaxonPhotos: ( t: { id?: number } ) => `/taxa/${t?.id}/browse_photos`
} ) );

jest.mock( "../../../shared/components/taxon_photo", ( ) => ( {
  __esModule: true,
  default: ( props: { photo?: { id?: number } } ) => (
    <div data-testid="taxon-photo" data-photo-id={props.photo?.id} />
  )
} ) );

jest.mock( "../../../shared/components/split_taxon", ( ) => ( {
  __esModule: true,
  default: ( props: { taxon?: { id?: number }; url?: string } ) => (
    <span data-testid="split-taxon" data-taxon-id={props.taxon?.id} data-url={props.url} />
  )
} ) );

// jsdom can't scroll, so render the children directly.
jest.mock( "react-infinite-scroller", ( ) => ( {
  __esModule: true,
  default: ( props: { className?: string; children?: React.ReactNode } ) => (
    <div data-testid="infinite-scroll" className={props.className}>{ props.children }</div>
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

const makeObsPhoto = ( id: number ): ObsPhoto => ( {
  photo: {
    id,
    photoUrl: ( ) => "",
    dimensions: ( ) => null
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

afterEach( ( ) => {
  // These are real globals, not jest mocks, so clearMocks won't reset them.
  // Remove them so they can't leak into other test files in the same worker.
  delete ( global as unknown as Record<string, unknown> ).iNaturalist;
  delete ( global as unknown as Record<string, unknown> ).$;
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
} );

describe( "PhotoBrowser results", ( ) => {
  it( "shows the ungrouped view when there are no groups", ( ) => {
    renderBrowser( { observationPhotos: [makeObsPhoto( 1 )] } );
    expect( screen.getByTestId( "infinite-scroll" ) ).toBeInTheDocument( );
    expect( screen.getAllByTestId( "taxon-photo" ) ).toHaveLength( 1 );
  } );

  it( "renders photos after switching into a grouping (groups fill in asynchronously)", ( ) => {
    const grouping = { param: "field:foo" };
    const groupedPhotos: Record<string, Group> = {};

    // 1. No grouping selected yet — ungrouped view.
    const { rerender } = render(
      <PhotoBrowser {...baseProps} grouping={{}} groupedPhotos={{}} />
    );
    expect( screen.getByTestId( "infinite-scroll" ) ).toBeInTheDocument( );

    // 2. User switches to a grouping: the group exists but its photos haven't loaded.
    groupedPhotos.adult = makeGroup( "Adult", { id: 9 }, [] );
    rerender(
      <PhotoBrowser {...baseProps} grouping={grouping} groupedPhotos={groupedPhotos} />
    );
    expect( screen.queryByTestId( "taxon-photo" ) ).not.toBeInTheDocument( );

    // 3. Fetch resolves: photos are dropped into the same container, in place.
    groupedPhotos.adult = makeGroup( "Adult", { id: 9 }, [makeObsPhoto( 1 ), makeObsPhoto( 2 )] );
    rerender(
      <PhotoBrowser {...baseProps} grouping={grouping} groupedPhotos={groupedPhotos} />
    );
    expect( screen.getAllByTestId( "taxon-photo" ) ).toHaveLength( 2 );
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
      .toHaveAttribute( "data-active", "false" );
  } );

  it( "marks the per-term item active when that term grouping is selected", ( ) => {
    // setGrouping stores the param as `terms:<attribute id>` (see ducks/photos),
    // so the term menu item must compare against that, not a `field:<label>` form.
    renderBrowser( { grouping: { param: "terms:1", values: 1 }, terms } );
    const menu = within( screen.getByTestId( "dropdown-grouping-control" ) );
    expect( menu.getByRole( "menuitem", { name: "none" } ) ).toHaveAttribute( "data-active", "false" );
    expect( menu.getByRole( "menuitem", { name: "taxonomic" } ) ).toHaveAttribute( "data-active", "false" );
    expect( menu.getByRole( "menuitem", { name: "controlled_term_labels.life_stage" } ) )
      .toHaveAttribute( "data-active", "true" );
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

  it( "marks date_added active when order_by is created_at", ( ) => {
    // Guards against regressing the active check back to comparing the grouping
    // object (which is never the string "created_at") instead of params.order_by.
    renderBrowser( { params: { order_by: "created_at" } } );
    const dropdown = within( screen.getByTestId( "dropdown-sort-control" ) );
    expect( dropdown.getByRole( "menuitem", { name: "date_added" } ) ).toHaveAttribute( "data-active", "true" );
    expect( dropdown.getByRole( "menuitem", { name: "faves" } ) ).toHaveAttribute( "data-active", "false" );
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

import React from "react";
import { render, screen } from "@testing-library/react";

// Stub shared components that transitively load browser-only deps (heic-to, etc.)
jest.mock( "../../../taxa/shared/util", ( ) => ( {
  urlForTaxon: t => ( t ? `/taxa/${t.id}` : null )
} ) );
jest.mock( "../../../shared/components/split_taxon", ( ) => ( {
  __esModule: true,
  default: ( { taxon } ) => <span>{ taxon?.name }</span>
} ) );
jest.mock( "../../../shared/components/user_text", ( ) => ( {
  __esModule: true,
  default: ( { text } ) => <span>{ text }</span>
} ) );
jest.mock( "../../../shared/components/user_image", ( ) => ( {
  __esModule: true,
  default: ( ) => null
} ) );
jest.mock( "../../../shared/components/user_link", ( ) => ( {
  __esModule: true,
  default: ( { user } ) => <span>{ user?.login }</span>
} ) );
jest.mock( "../../../shared/components/inativersary", ( ) => ( {
  __esModule: true,
  default: ( ) => null
} ) );
jest.mock( "../../../shared/components/text_editor", ( ) => ( {
  __esModule: true,
  default: ( ) => null
} ) );
jest.mock( "../../../shared/containers/hidden_content_message_container", ( ) => ( {
  __esModule: true,
  default: ( ) => null
} ) );
jest.mock( "./activity_item_menu", ( ) => ( {
  __esModule: true,
  default: ( ) => null
} ) );
jest.mock( "./hidden_activity_item", ( ) => ( {
  __esModule: true,
  default: ( ) => <div data-testid="hidden-activity-item" />
} ) );
jest.mock( "./users_popover", ( ) => ( {
  __esModule: true,
  default: ( ) => null
} ) );

// jQuery: used in componentDidUpdate for textarea mentions and inline in render
// for OverlayTrigger container ($(...).get(0)).
global.$ = jest.fn( ).mockReturnValue( { textcompleteUsers: jest.fn( ), get: ( ) => null } );

// eslint-disable-next-line import/first
import ActivityItem from "./activity_item";

const noop = jest.fn( );

const baseItem = {
  id: 1,
  uuid: "abc-123",
  user: { id: 10, login: "alice" },
  taxon: {
    id: 5,
    name: "Quercus alba",
    rank: "species",
    iconic_taxon_name: "Plantae",
    is_active: true
  },
  created_at: "2024-01-01T00:00:00Z",
  category: null,
  current: true,
  flags: [],
  body: null,
  firstDisplay: false
};

const baseProps = {
  observation: { id: 99, user: { id: 20, login: "bob" }, identifications: [] },
  config: {
    currentUser: { id: 30, roles: [] },
    currentUserCanInteractWithResource: ( ) => false
  },
  item: baseItem,
  performOrOpenConfirmationModal: noop,
  setFlaggingModalState: noop
};

describe( "ActivityItem", ( ) => {
  it( "renders an identification item with its taxon name", ( ) => {
    render( <ActivityItem {...baseProps} /> );
    expect( screen.getByText( "Quercus alba" ) ).toBeInTheDocument( );
  } );

  it( "renders a comment item with its body text", ( ) => {
    const item = { ...baseItem, taxon: null, body: "Nice find!" };
    render( <ActivityItem {...baseProps} item={item} /> );
    expect( screen.getByText( "Nice find!" ) ).toBeInTheDocument( );
  } );

  it( "maverick status badge has title attribute", ( ) => {
    const item = { ...baseItem, category: "maverick" };
    render( <ActivityItem {...baseProps} item={item} /> );
    expect( screen.getByTitle( "maverick" ) ).toBeInTheDocument( );
    // Label text is wrapped in item-status-label span for responsive hiding.
    expect( screen.getByTitle( "maverick" ).querySelector( ".item-status-label" ) ).toBeInTheDocument( );
  } );

  it( "improving status badge has title attribute", ( ) => {
    const item = { ...baseItem, category: "improving" };
    render( <ActivityItem {...baseProps} item={item} /> );
    expect( screen.getByTitle( "improving" ) ).toBeInTheDocument( );
  } );

  it( "leading status badge has title attribute", ( ) => {
    const item = { ...baseItem, category: "leading" };
    render( <ActivityItem {...baseProps} item={item} /> );
    expect( screen.getByTitle( "leading" ) ).toBeInTheDocument( );
  } );

  it( "withdrawn status badge has title attribute when identification is not current", ( ) => {
    const item = { ...baseItem, current: false };
    render( <ActivityItem {...baseProps} item={item} /> );
    expect( screen.getByTitle( "id_withdrawn" ) ).toBeInTheDocument( );
  } );

  it( "flagged status badge has title attribute when item has unresolved flags", ( ) => {
    const item = { ...baseItem, flags: [{ resolved: false }] };
    render( <ActivityItem {...baseProps} item={item} /> );
    expect( screen.getByTitle( "flagged_" ) ).toBeInTheDocument( );
  } );

  it( "renders HiddenActivityItem when item is hidden and viewer cannot see hidden content", ( ) => {
    const item = { ...baseItem, hidden: true };
    render( <ActivityItem {...baseProps} item={item} /> );
    expect( screen.getByTestId( "hidden-activity-item" ) ).toBeInTheDocument( );
  } );
} );

import React from "react";
import { render, screen } from "@testing-library/react";
import type { Observation } from "../../../shared/types";
import type { MoreFromUserProps } from "./more_from_user";

// TaxonThumbnail transitively loads browser-only deps (heic-to) via split_taxon /
// taxa/shared/util; stub them like the shared component tests do.
jest.mock( "../../../taxa/shared/util", ( ) => ( {
  urlForTaxon: ( t: { id: number } | null ) => ( t ? `/taxa/${t.id}` : null )
} ) );
jest.mock( "../../../shared/components/cover_image", ( ) => ( {
  __esModule: true,
  default: ( { src }: { src?: string } ) => <div data-testid="cover" data-src={src} />
} ) );
jest.mock( "../../../shared/components/split_taxon", ( ) => ( {
  __esModule: true,
  default: ( { taxon }: { taxon?: { name?: string } } ) => <span>{ taxon?.name }</span>
} ) );

// eslint-disable-next-line import/first
import MoreFromUser from "./more_from_user";

const makeObs = ( i: number ) => ( {
  id: 100 + i,
  uuid: `uuid-${i}`,
  taxon: {
    id: i, name: `Taxon ${i}`, rank: "species", iconic_taxon_name: "Insecta"
  },
  photo: ( size?: string ) => (
    size ? `https://example.test/${size}-${i}.jpg` : `https://example.test/${i}.jpg`
  ),
  hasMedia: ( ) => true,
  hasSounds: ( ) => false
} as unknown as Observation );

const props = {
  observation: { id: 99, user: { login: "bob" }, observed_on: "2024-01-01" },
  otherObservations: {
    earlierUserObservations: [],
    laterUserObservations: [0, 1, 2, 3, 4, 5].map( makeObs )
  },
  showNewObservation: ( ) => undefined,
  config: { currentUser: { id: 1 } }
} as unknown as MoreFromUserProps;

describe( "MoreFromUser", ( ) => {
  it( "renders a carousel of the user's other observations", ( ) => {
    render( <MoreFromUser {...props} /> );
    // Carousel renders prev/next nav buttons (titles come from I18n keys).
    expect( screen.getByTitle( "next_taxon_short" ) ).toBeInTheDocument( );
    // First observation's taxon shows in its thumbnail caption.
    expect( screen.getByText( "Taxon 0" ) ).toBeInTheDocument( );
  } );

  it( "renders an empty div when there are no observations", ( ) => {
    const { container } = render(
      <MoreFromUser
        {...props}
        otherObservations={{ earlierUserObservations: [], laterUserObservations: [] }}
      />
    );
    const root = container.firstChild as HTMLElement;
    expect( root.tagName ).toBe( "DIV" );
    expect( root.children.length ).toBe( 0 );
  } );

  it( "shows observations from earlierUserObservations when there are no later ones", ( ) => {
    render(
      <MoreFromUser
        {...props}
        otherObservations={{
          earlierUserObservations: [0, 1, 2].map( makeObs ),
          laterUserObservations: []
        }}
      />
    );
    expect( screen.getByText( "Taxon 0" ) ).toBeInTheDocument( );
  } );

  it( "shows date links when observation has an observed_on date", ( ) => {
    const { container } = render( <MoreFromUser {...props} /> );
    // The calendar link is only present when a date can be parsed from observed_on.
    const calendarLinks = container.querySelectorAll( "a[href*='/calendar/']" );
    expect( calendarLinks.length ).toBeGreaterThan( 0 );
  } );

  it( "shows unknown taxon label for observations without a taxon", ( ) => {
    const noTaxonObs = {
      id: 200,
      uuid: "uuid-notaxon",
      taxon: null,
      photo: ( ) => null,
      hasMedia: ( ) => false,
      hasSounds: ( ) => false
    } as unknown as Observation;
    render(
      <MoreFromUser
        {...props}
        otherObservations={{
          earlierUserObservations: [],
          laterUserObservations: [noTaxonObs]
        }}
      />
    );
    // I18n stub returns the raw key; the unknown taxon renders with key "unknown".
    expect( screen.getByText( "unknown" ) ).toBeInTheDocument( );
  } );
} );

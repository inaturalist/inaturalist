import React from "react";
import { render, screen } from "@testing-library/react";

// TaxonThumbnail transitively loads browser-only deps (heic-to) via split_taxon /
// taxa/shared/util; stub them like the shared component tests do.
jest.mock( "../../../taxa/shared/util", ( ) => ( {
  urlForTaxon: t => ( t ? `/taxa/${t.id}` : null )
} ) );
jest.mock( "../../../shared/components/cover_image", ( ) => ( {
  __esModule: true,
  default: ( { src } ) => <div data-testid="cover" data-src={src} />
} ) );
jest.mock( "../../../shared/components/split_taxon", ( ) => ( {
  __esModule: true,
  default: ( { taxon } ) => <span>{ taxon?.name }</span>
} ) );

// eslint-disable-next-line import/first
import MoreFromUser from "./more_from_user";

// ponytail: minimal fakes, just the bits more_from_user touches.
const makeObs = i => ( {
  id: 100 + i,
  uuid: `uuid-${i}`,
  taxon: {
    id: i, name: `Taxon ${i}`, rank: "species", iconic_taxon_name: "Insecta"
  },
  photo: size => ( size ? `https://example.test/${size}-${i}.jpg` : `https://example.test/${i}.jpg` ),
  hasMedia: ( ) => true,
  hasSounds: ( ) => false
} );

const props = {
  observation: { id: 99, user: { login: "bob" }, observed_on: "2024-01-01" },
  otherObservations: {
    earlierUserObservations: [],
    laterUserObservations: [0, 1, 2, 3, 4, 5].map( makeObs )
  },
  showNewObservation: ( ) => undefined,
  config: { currentUser: { id: 1 } }
};

describe( "MoreFromUser", ( ) => {
  it( "renders a carousel of the user's other observations", ( ) => {
    render( <MoreFromUser {...props} /> );
    // Carousel renders prev/next nav buttons (titles come from I18n keys).
    expect( screen.getByTitle( "next_taxon_short" ) ).toBeInTheDocument( );
    // First observation's taxon shows in its thumbnail caption.
    expect( screen.getByText( "Taxon 0" ) ).toBeInTheDocument( );
  } );
} );

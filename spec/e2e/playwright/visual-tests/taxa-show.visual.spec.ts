import { test, Page } from "@playwright/test";
import { app, appMake } from "../support/on-rails";
import { buildTaxonShowResponse, mockTaxonShowApi } from "../fixtures/taxon-response";
import { expectVisualSnapshots } from "./helpers/visual-snapshot.helper";

// Tabs are activated by URL hash, which the app reads on load. Tab visibility is
// rank-gated: a species (rank_level 10) shows these, but NOT Highlights, which
// needs a genus (rank_level > 10). "articles" is the default, covered by the
// all-breakpoints sweep. Interactions is intentionally omitted.
const SPECIES_TABS = ["map", "taxonomy", "status", "similar", "identifications"] as const;

test.describe( "taxa show visual snapshots", () => {
  let speciesId: number;
  let genusId: number;

  test.beforeAll( async () => {
    const species = await appMake( "create", "taxon", {} );
    const genus = await appMake( "create", "taxon", {} );
    speciesId = species.id as number;
    genusId = genus.id as number;
    // /taxa/:id fetches its taxon JSON server-side and 404s without it.
    await app( "stub_inat_api", { path: `/taxa/${speciesId}?`, body: JSON.stringify( buildTaxonShowResponse( { id: speciesId } ) ) } );
    await app( "stub_inat_api", { path: `/taxa/${genusId}?`, body: JSON.stringify( buildTaxonShowResponse( { id: genusId, rank: "genus" } ) ) } );
  } );

  test.afterAll( async () => {
    await app( "stub_inat_api", { reset: true, path: `/taxa/${speciesId}?` } );
    await app( "stub_inat_api", { reset: true, path: `/taxa/${genusId}?` } );
  } );

  test.beforeEach( async ( { page } ) => {
    await mockTaxonShowApi( page, { speciesId, genusId } );
  } );

  // Photos + map tiles load from external hosts; mask for stability.
  const mask = ( page: Page ) => [
    page.locator( "#TaxonDetail img" ),
    page.locator( "#TaxonDetail .TaxonMap" ),
    page.locator( "#TaxonDetail .leaflet-container" )
  ];
  const common = { waitForSelector: "#TaxonDetail", mask };

  // Default (About) tab — the responsive baseline.
  expectVisualSnapshots( "taxa-show", () => `/taxa/${speciesId}`, common );

  // Each species tab.
  for ( const tab of SPECIES_TABS ) {
    expectVisualSnapshots( `taxa-show-${tab}`, () => `/taxa/${speciesId}#${tab}-tab`, common );
  }

  // Highlights tab (genus-only).
  expectVisualSnapshots( "taxa-show-highlights", () => `/taxa/${genusId}#highlights-tab`, common );
} );

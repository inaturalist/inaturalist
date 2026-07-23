import { test } from "@playwright/test";
import { app, appMake } from "../support/on-rails";
import { buildTaxonApiResponse, mockTaxaPhotosApi } from "../fixtures/taxon-response";
import { expectVisualSnapshots } from "./helpers/visual-snapshot.helper";

test.describe( "taxa browse_photos visual snapshots", () => {
  let taxonId: number;
  let stubPath: string;

  test.beforeAll( async () => {
    const taxon = await appMake( "create", "taxon", {} );
    taxonId = taxon.id as number;
    // browse_photos fetches taxon JSON server-side (INatAPIService.get_json),
    // which page.route can't intercept — stub it at the Rails layer instead.
    stubPath = `/taxa/${taxonId}?`;
    await app( "stub_inat_api", {
      path: stubPath,
      body: JSON.stringify( buildTaxonApiResponse( taxon ) )
    } );
  } );

  test.afterAll( async () => {
    await app( "stub_inat_api", { reset: true, path: stubPath } );
  } );

  test.beforeEach( async ( { page } ) => {
    await mockTaxaPhotosApi( page );
  } );

  expectVisualSnapshots( "taxa-browse-photos", () => `/taxa/${taxonId}/browse_photos`, {
    mask: page => [page.locator( ".TaxonPhoto img" )]
  } );
} );

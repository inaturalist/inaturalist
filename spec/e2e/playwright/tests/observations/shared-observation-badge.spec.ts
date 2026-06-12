import { test, expect, Page } from "@playwright/test";
import { appMake } from "../../support/on-rails";

// The Angular grid fetches the V2 search from the configured inaturalist_api_url
// host; the API search call (unlike the page URL) always carries a `fields=`
// param, so we route on that to avoid intercepting the page navigation itself.
const SEARCH_ROUTE = /\/observations\?.*fields=/;

async function mockGridSearch( page: Page, results: Record<string, unknown>[] ): Promise<void> {
  await page.route( SEARCH_ROUTE, async route => {
    await route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( {
        total_results: results.length,
        page: 1,
        per_page: 30,
        results
      } )
    } );
  } );
}

function gridObservation( id: number, user: Record<string, unknown> ) {
  return {
    id,
    uuid: `uuid-${id}`,
    quality_grade: "research",
    user,
    taxon: { id: 1, name: "Test Species", rank: "species", iconic_taxon_name: "Animalia" },
    photos: [],
    sounds: [],
    identifications_count: 1,
    comments_count: 0,
    faves_count: 0
  };
}

test.describe( "Shared observation badge (V2 grid)", () => {
  test( "shows the badge on an observation owned by someone other than the queried user", async ( { page } ) => {
    const owner = { id: 101, login: "real_owner", icon_url: null };
    await mockGridSearch( page, [gridObservation( 1, owner )] );
    await page.goto( "/observations?user_id=other_login" );
    await expect( page.locator( ".shared-observation-marker" ).first() ).toBeVisible( { timeout: 15_000 } );
  } );

  test( "does not show the badge on the queried user's own observation", async ( { page } ) => {
    const owner = { id: 102, login: "self_login", icon_url: null };
    await mockGridSearch( page, [gridObservation( 2, owner )] );
    await page.goto( "/observations?user_id=self_login" );
    await expect( page.locator( ".observation.observation-grid-cell" ).first() ).toBeVisible( { timeout: 15_000 } );
    await expect( page.locator( ".shared-observation-marker" ) ).toHaveCount( 0 );
  } );

  test( "does not show the badge when no user_id filter is set", async ( { page } ) => {
    const owner = { id: 103, login: "anyone", icon_url: null };
    await mockGridSearch( page, [gridObservation( 3, owner )] );
    await page.goto( "/observations" );
    await expect( page.locator( ".observation.observation-grid-cell" ).first() ).toBeVisible( { timeout: 15_000 } );
    await expect( page.locator( ".shared-observation-marker" ) ).toHaveCount( 0 );
  } );
} );

test.describe( "Shared observation marker (legacy by_login list)", () => {
  test( "marks an observation the viewed user is an additional observer on", async ( { page } ) => {
    const creator = await appMake( "create", "user", {} );
    const observer = await appMake( "create", "user", {} );
    const obs = await appMake( "create", "observation", {
      user_id: creator.id,
      latitude: 1,
      longitude: 1,
      observed_on_string: "yesterday"
    } );
    await appMake( "create", "additional_observer", {
      observation_id: obs.id,
      user_id: observer.id,
      added_by_user_id: creator.id
    } );

    await page.goto( `/observations/${observer.login as string}` );
    await expect( page.locator( ".shared-observation-marker" ).first() ).toBeVisible( { timeout: 15_000 } );
  } );
} );

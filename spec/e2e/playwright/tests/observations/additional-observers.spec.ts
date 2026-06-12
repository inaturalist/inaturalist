import { test, expect } from "@playwright/test";
import { ObservationDetailPage } from "../../page-objects/observation-detail.page";
import { mockObservationFetch } from "../../fixtures/observation-response";
import { appMake } from "../../support/on-rails";
import { login } from "../../helpers/auth.helper";

// The User blueprint defaults the password to "monkey", so we create users with
// a known email and log in as them to control whether the viewer is the creator.
const PASSWORD = "monkey";

test.describe( "Additional observers widget", () => {
  test( "the creator can add an additional observer", async ( { page } ) => {
    const creator = await appMake( "create", "user", {
      email: "ao-creator@example.com",
      password: PASSWORD
    } );
    const otherUser = await appMake( "create", "user", { login: "ao_pickme" } );
    const taxon = await appMake( "create", "taxon", {} );
    const obs = await appMake( "create", "observation", {
      user_id: creator.id,
      taxon_id: taxon.id,
      latitude: 1,
      longitude: 1,
      observed_on_string: "yesterday"
    } );

    await login( page, creator.email as string, PASSWORD );
    await mockObservationFetch( page, obs );

    // Mock the user autocomplete API (test env uses localhost:5000 which is not running).
    await page.route( /\/users\/autocomplete/, async route => {
      const url = new URL( route.request().url() );
      const callback = url.searchParams.get( "callback" ) || "projectAutocompleteCallback";
      const payload = {
        total_results: 1,
        results: [
          {
            id: otherUser.id as number,
            login: otherUser.login as string,
            icon_url: null,
            name: otherUser.login as string
          }
        ]
      };
      await route.fulfill( {
        status: 200,
        contentType: "application/javascript",
        body: `${callback}(${JSON.stringify( payload )})`
      } );
    } );

    const detailPage = new ObservationDetailPage( page );
    await detailPage.goto( obs.id as number );

    // The creator-only widget is present.
    await expect( detailPage.getAdditionalObserversWidget() ).toBeVisible( { timeout: 15_000 } );

    // Pick the other user via the autocomplete; the row should appear
    // optimistically (before the API reflects the new join record).
    const autocomplete = detailPage.getAdditionalObserverAutocomplete();
    await autocomplete.fill( otherUser.login as string );
    const suggestion = page.locator(
      `.ac-menu li:has-text("${otherUser.login as string}")`
    ).first();
    await suggestion.click();

    await expect(
      detailPage.getAdditionalObserverRows().filter( { hasText: otherUser.login as string } )
    ).toBeVisible( { timeout: 15_000 } );
  } );

  test( "a non-creator does not see the widget", async ( { page } ) => {
    const creator = await appMake( "create", "user", {} );
    const viewer = await appMake( "create", "user", {
      email: "ao-viewer@example.com",
      password: PASSWORD
    } );
    const taxon = await appMake( "create", "taxon", {} );
    const obs = await appMake( "create", "observation", {
      user_id: creator.id,
      taxon_id: taxon.id,
      latitude: 1,
      longitude: 1,
      observed_on_string: "yesterday"
    } );

    await login( page, viewer.email as string, PASSWORD );
    await mockObservationFetch( page, obs );

    const detailPage = new ObservationDetailPage( page );
    await detailPage.goto( obs.id as number );

    await expect( detailPage.getObserver() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getAdditionalObserversWidget() ).toHaveCount( 0 );
  } );
} );

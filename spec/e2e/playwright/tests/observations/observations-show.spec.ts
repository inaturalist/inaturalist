import { test, expect } from "@playwright/test";
import { ObservationDetailPage } from "../../page-objects/observation-detail.page";
import { mockObservationFetch } from "../../fixtures/observation-response";
import { app, appClean, appMake } from "../../support/on-rails";

test.describe( "Observation detail page", () => {
  let detailPage: ObservationDetailPage;

  test.beforeEach( async ( { page } ) => {
    await appClean();
    const user = await appMake( "create", "user", {} );
    const taxon = await appMake( "create", "taxon", {});
    const obs = await appMake( "create", "observation", {
      user_id: user.id,
      taxon_id: taxon.id,
      latitude: 1,
      longitude: 1,
      observed_on_string: "yesterday"
    } );
    await mockObservationFetch( page, obs );
    detailPage = new ObservationDetailPage( page );
    await detailPage.goto( obs.id as number );
  } );

  test( "loads and displays core observation content", async () => {
    await expect( detailPage.getPhoto() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getTaxonName() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getObserver() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getMap() ).toBeVisible( { timeout: 15_000 } );
  } );
} );

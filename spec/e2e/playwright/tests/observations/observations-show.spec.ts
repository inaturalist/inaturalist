import { test, expect } from "@playwright/test";
import { ObservationDetailPage } from "../../page-objects/observation-detail.page";
import { mockObservationFetch } from "../../fixtures/observation-response";
import { appMachinistHelper, appClean, appMake } from "../../support/on-rails";

test.describe( "Observation detail page", () => {
  let detailPage: ObservationDetailPage;

  test.beforeEach( async ( { page } ) => {
    await appClean();
    detailPage = new ObservationDetailPage( page );
    const obsUser = await appMake( "create", "user", { email: `e2e_obs_${Date.now()}@inaturalist.org` } );
    const identUser = await appMake( "create", "user", { email: `e2e_ident_${Date.now()}@inaturalist.org` } );
    const obs = await appMachinistHelper( "make_research_grade_observation", {
      user_id: obsUser["id"] as number,
      identifier_user_id: identUser["id"] as number
    } );
    await mockObservationFetch( page, obs );
    await detailPage.goto( obs["id"] as number );
  } );

  test( "loads and displays core observation content", async () => {
    await detailPage.assertNoServerError();
    await expect( detailPage.getPhoto() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getTaxonName() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getObserver() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getMap() ).toBeVisible( { timeout: 15_000 } );
  } );
} );

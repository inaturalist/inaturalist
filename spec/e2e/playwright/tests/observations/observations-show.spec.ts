import { test, expect } from "@playwright/test";
import { ObservationDetailPage } from "../../page-objects/observation-detail.page";
import testData from "../../fixtures/test-data.json";
import { appMake, appMachinistHelper } from "../../support/on-rails";

test.describe( "Observation detail page", () => {
  let detailPage: ObservationDetailPage;

  test.beforeEach( async ( { page } ) => {
    detailPage = new ObservationDetailPage( page );
    const obs = await appMake( "create", "observation", { description: "Test observation" } );
    await detailPage.goto( obs.id as number );
  } );

  test( "page loads without errors", async () => {
    await detailPage.assertNoServerError();
  } );

  test( "displays observation photo or media", async () => {
    await expect( detailPage.getPhoto() ).toBeVisible( { timeout: 15_000 } );
  } );

  test( "displays taxon identification", async () => {
    await expect( detailPage.getTaxonName() ).toBeVisible( { timeout: 15_000 } );
  } );

  test( "displays observer info", async () => {
    await expect( detailPage.getObserver() ).toBeVisible( { timeout: 15_000 } );
  } );

  test( "displays map", async () => {
    await expect( detailPage.getMap() ).toBeVisible( { timeout: 15_000 } );
  } );
} );

import { test, expect } from "@playwright/test";
import { ObservationDetailPage } from "../../page-objects/observation-detail.page";
import testData from "../../fixtures/test-data.json";

test.describe( "Observation detail page", () => {
  let detailPage: ObservationDetailPage;

  test.beforeEach( async ( { page } ) => {
    detailPage = new ObservationDetailPage( page );
    await detailPage.goto( testData.observations.knownId );
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

import { test, expect } from "@playwright/test";
import { TaxonDetailPage } from "../../page-objects/taxon-detail.page";
import testData from "../../fixtures/test-data.json";

test.describe( "Taxon detail page", () => {
  let taxonPage: TaxonDetailPage;

  test.beforeEach( async ( { page } ) => {
    taxonPage = new TaxonDetailPage( page );
    await taxonPage.goto( testData.taxa.knownId );
  } );

  test( "page loads without errors", async () => {
    await taxonPage.assertNoServerError();
  } );

  test( "displays taxon name", async () => {
    await expect( taxonPage.getTaxonName() ).toBeVisible( { timeout: 15_000 } );
  } );

  test( "displays photos", async () => {
    await expect( taxonPage.getPhotos() ).toBeVisible( { timeout: 15_000 } );
  } );

  test( "displays taxonomy breadcrumb", async () => {
    await expect( taxonPage.getTaxonomyBreadcrumb() ).toBeVisible( { timeout: 15_000 } );
  } );

  test( "displays tabs", async () => {
    await expect( taxonPage.getTabs() ).toBeVisible( { timeout: 15_000 } );
  } );
} );

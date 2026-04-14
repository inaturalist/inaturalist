import { test, expect } from "@playwright/test";
import { ObservationSearchPage } from "../../page-objects/observation-search.page";

test.describe( "Observations index", () => {
  let searchPage: ObservationSearchPage;

  test.beforeEach( async ( { page } ) => {
    searchPage = new ObservationSearchPage( page );
    await searchPage.goto();
  } );

  test( "page loads without errors", async () => {
    await searchPage.assertNoServerError();
    const title = await searchPage.getPageTitle();
    expect( title.length ).toBeGreaterThan( 0 );
  } );

  test( "displays header", async () => {
    await expect( searchPage.getHeader() ).toBeVisible();
  } );

  test( "grid view control is present", async () => {
    await expect( searchPage.getGridView() ).toBeVisible();
  } );

  test( "can switch to map view", async () => {
    const mapControl = searchPage.getMapView();
    if ( await mapControl.isVisible() ) {
      await searchPage.switchToMap();
      await expect( searchPage.page.locator( "[class*='map'], .map" ).first() ).toBeVisible();
    }
  } );

  test( "can switch to table view", async () => {
    const tableControl = searchPage.getTableView();
    if ( await tableControl.isVisible() ) {
      await searchPage.switchToTable();
      await expect( searchPage.page.locator( "table, .table" ).first() ).toBeVisible();
    }
  } );
} );

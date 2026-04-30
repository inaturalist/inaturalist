import { test, expect } from "@playwright/test";
import { ObservationSearchPage } from "../../page-objects/observation-search.page";

test.describe( "Observations index — search & stats", () => {
  let searchPage: ObservationSearchPage;

  test.beforeEach( async ( { page } ) => {
    searchPage = new ObservationSearchPage( page );
    await searchPage.goto();
  } );

  test( "displays the Observations heading", async () => {
    await expect( searchPage.getHeading() ).toBeVisible();
    await expect( searchPage.getHeading() ).toHaveText( /observations/i );
  } );

  test( "renders the stats container with four stat columns", async () => {
    await expect( searchPage.getStatsContainer() ).toBeVisible();
    await expect( searchPage.getObservationsStat() ).toBeVisible();
    await expect( searchPage.getStatColumns() ).toHaveCount( 4 );
  } );

  test( "exposes taxon and place search inputs", async () => {
    await expect( searchPage.getTaxonNameInput() ).toBeVisible();
    await expect( searchPage.getPlaceNameInput() ).toBeVisible();
  } );

  test( "accepts text input in the taxon name filter", async () => {
    const input = searchPage.getTaxonNameInput();
    await input.fill( "Mammalia" );
    await expect( input ).toHaveValue( "Mammalia" );
  } );

  test( "shows the filters dropdown toggle", async () => {
    await expect( searchPage.getFilterToggle() ).toBeVisible();
  } );

  test( "renders the results container", async () => {
    await expect( searchPage.getResultsContainer() ).toBeVisible();
  } );

  test( "map/grid/table subview controls are all present", async () => {
    await expect( searchPage.getMapView() ).toBeVisible();
    await expect( searchPage.getGridView() ).toBeVisible();
    await expect( searchPage.getTableView() ).toBeVisible();
  } );
} );

import { test, expect } from "@playwright/test";
import { ObservationSearchPage } from "../../page-objects/observation-search.page";

test.describe( "Observations map — boundary drawing tools", () => {
  let searchPage: ObservationSearchPage;

  test.beforeEach( async ( { page } ) => {
    searchPage = new ObservationSearchPage( page );
  } );

  test.describe( "toolbar controls", () => {
    test.beforeEach( async () => {
      await searchPage.goto( "subview=map" );
    } );

    test( "rectangle and circle boundary buttons are visible", async () => {
      await expect( searchPage.getRectangleBoundaryButton() ).toBeVisible();
      await expect( searchPage.getCircleBoundaryButton() ).toBeVisible();
    } );

    test( "reset button is hidden when no boundary is active", async () => {
      await expect( searchPage.getResetBoundaryButton() ).toBeHidden();
    } );
  } );

  test.describe( "rectangular boundary", () => {
    test( "filters observations to a rectangular region via URL params", async () => {
      // North America bounding box
      await searchPage.gotoWithRectBoundary( 50, -70, 25, -125 );

      await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();
      await expect( searchPage.getResetBoundaryButton() ).toBeVisible();

      const obsValue = searchPage.getObservationsStatValue();
      await expect( obsValue ).not.toHaveText( "0" );
    } );

    test( "updates observation count when boundary changes", async () => {
      // Broad North America boundary
      await searchPage.gotoWithRectBoundary( 50, -70, 25, -125 );

      const obsValue = searchPage.getObservationsStatValue();
      await expect( obsValue ).toBeVisible();
      const broadCount = await obsValue.textContent();

      // Navigate to a narrower boundary (small area in central US)
      await searchPage.gotoWithRectBoundary( 40, -95, 35, -100 );

      await expect( obsValue ).toBeVisible();
      await expect( obsValue ).not.toHaveText( broadCount! );
    } );

    test( "preserves four stat columns with boundary active", async () => {
      await searchPage.gotoWithRectBoundary( 50, -70, 25, -125 );
      await expect( searchPage.getStatColumns() ).toHaveCount( 4 );
    } );
  } );

  test.describe( "circular boundary", () => {
    test( "filters observations to a circular region via URL params", async () => {
      // 500km radius around Paris
      await searchPage.gotoWithCircleBoundary( 48.8, 2.3, 500 );

      await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();

      const obsValue = searchPage.getObservationsStatValue();
      await expect( obsValue ).not.toHaveText( "0" );
    } );

    test( "shows different results for different circle locations", async () => {
      // Europe
      await searchPage.gotoWithCircleBoundary( 48.8, 2.3, 500 );

      const obsValue = searchPage.getObservationsStatValue();
      await expect( obsValue ).toBeVisible();
      const europeCount = await obsValue.textContent();

      // Australia
      await searchPage.gotoWithCircleBoundary( -33.8, 151.2, 500 );

      await expect( obsValue ).toBeVisible();
      await expect( obsValue ).not.toHaveText( europeCount! );
    } );
  } );

  test.describe( "clearing boundaries", () => {
    test( "clear boundary icon removes the custom boundary", async () => {
      await searchPage.gotoWithRectBoundary( 50, -70, 25, -125 );
      await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();

      const obsBeforeClear = await searchPage.getObservationsStatValue().textContent();

      await searchPage.getClearBoundaryIcon().click();

      await expect( searchPage.getCustomBoundaryLabel() ).toBeHidden();

      // Observation count should increase back toward the global total
      const obsAfterClear = searchPage.getObservationsStatValue();
      await expect( obsAfterClear ).not.toHaveText( obsBeforeClear! );
    } );

    test( "URL params are removed after clearing boundary", async ( { page } ) => {
      await searchPage.gotoWithRectBoundary( 50, -70, 25, -125 );
      await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();

      await searchPage.getClearBoundaryIcon().click();

      await expect( searchPage.getCustomBoundaryLabel() ).toBeHidden();
      await expect( page ).not.toHaveURL( /nelat/ );
      await expect( page ).not.toHaveURL( /swlat/ );
    } );
  } );
} );

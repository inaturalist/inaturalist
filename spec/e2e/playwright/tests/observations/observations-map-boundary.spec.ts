import { test, expect } from "@playwright/test";
import { ObservationSearchPage } from "../../page-objects/observation-search.page";

test.describe( "Observations map — boundary drawing tools", () => {
  let searchPage: ObservationSearchPage;

  test.beforeEach( async ( { page } ) => {
    searchPage = new ObservationSearchPage( page );
  } );

  test( "boundary state transitions: toolbar → rect → circle → clear", async ( { page } ) => {
    // Initial state: drawing controls visible, reset button absent
    await searchPage.goto( "subview=map" );
    await expect( searchPage.getRectangleBoundaryButton() ).toBeVisible();
    await expect( searchPage.getCircleBoundaryButton() ).toBeVisible();
    await expect( searchPage.getResetBoundaryButton() ).toBeHidden();

    // Broad rectangular boundary (North America)
    await searchPage.gotoWithRectBoundary( 50, -70, 25, -125 );
    await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();
    await expect( searchPage.getResetBoundaryButton() ).toBeVisible();
    await expect( searchPage.getStatColumns() ).toHaveCount( 4 );
    await expect( page ).toHaveURL( /nelat=/ );
    await expect( page ).toHaveURL( /swlat=/ );

    // Narrower rect boundary — boundary UI remains active, URL params update
    await searchPage.gotoWithRectBoundary( 40, -95, 35, -100 );
    await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();
    await expect( searchPage.getResetBoundaryButton() ).toBeVisible();
    await expect( page ).toHaveURL( /nelat=40/ );

    // Switch to circle boundary (Paris 500 km)
    await searchPage.gotoWithCircleBoundary( 48.8, 2.3, 500 );
    await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();
    await expect( page ).toHaveURL( /radius=/ );
    await expect( page ).not.toHaveURL( /nelat=/ );

    // Same radius, different continent (Sydney) — boundary still active
    await searchPage.gotoWithCircleBoundary( -33.8, 151.2, 500 );
    await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();
    await expect( page ).toHaveURL( /radius=/ );

    // Clear the boundary
    await searchPage.getClearBoundaryIcon().click();
    await expect( searchPage.getCustomBoundaryLabel() ).toBeHidden();
    await expect( searchPage.getResetBoundaryButton() ).toBeHidden();
    await expect( page ).not.toHaveURL( /nelat/ );
    await expect( page ).not.toHaveURL( /swlat/ );
    await expect( page ).not.toHaveURL( /radius/ );
  } );
} );

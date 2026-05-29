import { test, expect, Page } from "@playwright/test";
import { ObservationSearchPage } from "../../page-objects/observation-search.page";

// --- Google Maps JS API helpers ---

// Polls until the Angular MapController has an active shape overlay whose
// bounds/center method returns a non-null value (i.e. the overlay is fully
// initialised on the map, not just constructed).
async function waitForShape( page: Page ): Promise<void> {
  await page.waitForFunction(
    () => {
      const scope = ( window as any ).angular
        ?.element( document.querySelector( "#observations-map" ) )
        ?.scope();
      const layer = scope?.selectedPlaceLayer;
      if ( !layer ) return false;
      if ( layer.getBounds ) return layer.getBounds() != null;
      if ( layer.getCenter ) return layer.getCenter() != null;
      return false;
    },
    { timeout: 15_000 }
  );
}

// Returns the current rectangle overlay bounds from the Angular scope.
async function getRectBounds( page: Page ) {
  return page.evaluate( () => {
    const b = ( window as any ).angular
      .element( document.querySelector( "#observations-map" ) )
      .scope()
      .selectedPlaceLayer.getBounds();
    return {
      nelat: b.getNorthEast().lat(),
      nelng: b.getNorthEast().lng(),
      swlat: b.getSouthWest().lat(),
      swlng: b.getSouthWest().lng()
    };
  } );
}

// Returns the current circle overlay center and radius from the Angular scope.
async function getCircle( page: Page ) {
  return page.evaluate( () => {
    const shape = ( window as any ).angular
      .element( document.querySelector( "#observations-map" ) )
      .scope().selectedPlaceLayer;
    return {
      lat: shape.getCenter().lat(),
      lng: shape.getCenter().lng(),
      radiusMeters: shape.getRadius()
    };
  } );
}

// --- Tests ---

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

  test.describe( "interactive resize via Google Maps overlay API", () => {
    // Expands the rectangle by calling setBounds() on the overlay object.  This
    // fires the same `bounds_changed` listener that a user drag would trigger,
    // exercising the full Angular → URL update path without needing to
    // pixel-perfectly target a small SVG handle at low zoom.
    // Skipped: Google Maps fails to load in the test browser ("This page didn't
    // load Google Maps correctly"), so the Angular MapController never
    // instantiates `selectedPlaceLayer` and `waitForShape` times out. Needs a
    // Maps API mock or a working Maps key for the test referrer. Revisit.
    test.skip( "expanding the NE corner via setBounds updates the rectangular boundary", async ( { page } ) => {
      await searchPage.gotoWithRectBoundary( 45, -75, 30, -120 );
      await waitForShape( page );

      const before = await getRectBounds( page );
      const nelatBefore = parseFloat(
        new URL( page.url() ).searchParams.get( "nelat" ) ?? "0"
      );

      await page.evaluate( () => {
        const scope = ( window as any ).angular
          .element( document.querySelector( "#observations-map" ) )
          .scope();
        const rect = scope.selectedPlaceLayer;
        const b = rect.getBounds();
        const sw = b.getSouthWest();
        const ne = b.getNorthEast();
        rect.setBounds( new ( window as any ).google.maps.LatLngBounds(
          sw,
          new ( window as any ).google.maps.LatLng( ne.lat() + 5, ne.lng() + 5 )
        ) );
      } );

      await page.waitForURL(
        url => parseFloat( new URL( url ).searchParams.get( "nelat" ) ?? "0" ) > nelatBefore,
        { timeout: 8_000 }
      );

      const after = await getRectBounds( page );
      expect( after.nelat ).toBeGreaterThan( before.nelat );
      expect( after.nelng ).toBeGreaterThan( before.nelng );
    } );

    // Expands the circle by calling setRadius() on the overlay object.  This
    // fires the same `radius_changed` listener that a user drag would trigger,
    // exercising the full Angular → URL update path reliably across headless
    // and headed environments.
    // Skipped: same reason as the rectangle resize test above — Google Maps
    // does not load in the test browser, so the circle overlay never exists.
    test.skip( "expanding the radius via setRadius updates the circle boundary", async ( { page } ) => {
      await searchPage.gotoWithCircleBoundary( 48.8, 2.3, 300 );
      await waitForShape( page );

      const before = await getCircle( page );
      const radiusBefore = parseFloat(
        new URL( page.url() ).searchParams.get( "radius" ) ?? "0"
      );

      await page.evaluate( () => {
        const shape = ( window as any ).angular
          .element( document.querySelector( "#observations-map" ) )
          .scope().selectedPlaceLayer;
        shape.setRadius( shape.getRadius() * 1.5 );
      } );

      await page.waitForURL(
        url => parseFloat( new URL( url ).searchParams.get( "radius" ) ?? "0" ) !== radiusBefore,
        { timeout: 8_000 }
      );

      const after = await getCircle( page );
      expect( after.radiusMeters ).toBeGreaterThan( before.radiusMeters );
    } );
  } );
} );

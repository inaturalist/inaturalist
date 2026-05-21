import { test, expect, Page } from "@playwright/test";
import { ObservationSearchPage } from "../../page-objects/observation-search.page";

// --- Google Maps JS API helpers ---

// Polls until the Angular MapController has an active shape overlay with a bounds method.
async function waitForShape( page: Page ): Promise<void> {
  await page.waitForFunction(
    () => {
      const scope = ( window as any ).angular
        ?.element( document.querySelector( "#observations-map" ) )
        ?.scope();
      const layer = scope?.selectedPlaceLayer;
      return !!( layer?.getBounds || layer?.getCenter );
    },
    { timeout: 15_000 }
  );
}

// Converts a geographic coordinate to viewport pixel coordinates using the
// Google Maps Mercator projection and the map container's bounding rect.
async function latLngToViewportPx(
  page: Page,
  lat: number,
  lng: number
): Promise<{ x: number; y: number }> {
  return page.evaluate(
    ( { lat, lng } ) => {
      const scope = ( window as any ).angular
        .element( document.querySelector( "#observations-map" ) )
        .scope();
      const map = scope.map;
      const mapRect = map.getDiv().getBoundingClientRect();
      const scale = Math.pow( 2, map.getZoom() );
      const proj = map.getProjection();
      const nw = new ( window as any ).google.maps.LatLng(
        map.getBounds().getNorthEast().lat(),
        map.getBounds().getSouthWest().lng()
      );
      const origin = proj.fromLatLngToPoint( nw );
      const pt = proj.fromLatLngToPoint(
        new ( window as any ).google.maps.LatLng( lat, lng )
      );
      return {
        x: mapRect.left + ( pt.x - origin.x ) * scale,
        y: mapRect.top + ( pt.y - origin.y ) * scale
      };
    },
    { lat, lng }
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
    const obsValue = searchPage.getObservationsStatValue();
    await expect( obsValue ).not.toHaveText( "0" );
    const broadRectCount = await obsValue.textContent();

    // Narrower rect boundary → different (smaller) count
    await searchPage.gotoWithRectBoundary( 40, -95, 35, -100 );
    await expect( obsValue ).toBeVisible();
    await expect( obsValue ).not.toHaveText( broadRectCount! );

    // Switch to circle boundary (Paris 500 km)
    await searchPage.gotoWithCircleBoundary( 48.8, 2.3, 500 );
    await expect( searchPage.getCustomBoundaryLabel() ).toBeVisible();
    await expect( obsValue ).toBeVisible();
    const parisCount = await obsValue.textContent();
    await expect( obsValue ).not.toHaveText( "0" );

    // Same radius, different continent (Sydney) → different count
    await searchPage.gotoWithCircleBoundary( -33.8, 151.2, 500 );
    await expect( obsValue ).toBeVisible();
    await expect( obsValue ).not.toHaveText( parisCount! );

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
    test( "expanding the NE corner via setBounds updates the rectangular boundary", async ( { page } ) => {
      await searchPage.gotoWithRectBoundary( 45, -75, 30, -120 );
      await waitForShape( page );

      const before = await getRectBounds( page );

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

      await expect( page ).toHaveURL( /nelat=/, { timeout: 8_000 } );

      const after = await getRectBounds( page );
      expect( after.nelat ).toBeGreaterThan( before.nelat );
      expect( after.nelng ).toBeGreaterThan( before.nelng );
    } );

    // Drags the east edge handle outward using a viewport pixel coordinate
    // derived from the Maps projection API.
    test( "dragging the east edge handle increases the circle boundary radius", async ( { page } ) => {
      await searchPage.gotoWithCircleBoundary( 48.8, 2.3, 300 );
      await waitForShape( page );

      const before = await getCircle( page );

      // Easternmost edge, adjusted for longitude compression at this latitude
      const metersPerDegLng = 111_320 * Math.cos( ( before.lat * Math.PI ) / 180 );
      const edgeLng = before.lng + before.radiusMeters / metersPerDegLng;
      const from = await latLngToViewportPx( page, before.lat, edgeLng );

      const radiusBefore = parseFloat(
        new URL( page.url() ).searchParams.get( "radius" ) ?? "0"
      );

      await page.mouse.move( from.x, from.y );
      await page.mouse.down();
      await page.mouse.move( from.x + 50, from.y, { steps: 10 } );
      await page.mouse.up();

      await page.waitForURL(
        url => parseFloat( new URL( url ).searchParams.get( "radius" ) ?? "0" ) !== radiusBefore,
        { timeout: 8_000 }
      );

      const after = await getCircle( page );
      expect( after.radiusMeters ).toBeGreaterThan( before.radiusMeters );
    } );
  } );
} );

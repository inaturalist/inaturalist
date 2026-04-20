import { test, expect, Page } from "@playwright/test";
import { envConfig } from "../../../shared/env.config";

async function getDragIconScreenPos( page: Page ): Promise<{ x: number, y: number } | null> {
  return page.evaluate( () => {
    const imgs = Array.from( document.querySelectorAll( 'img[src*="drag-icon"]' ) ) as HTMLImageElement[];
    const visible = imgs.filter( img => {
      const r = img.getBoundingClientRect();
      return r.width > 0 && r.height > 0;
    } );
    if ( visible.length === 0 ) return null;
    const rect = visible[0].getBoundingClientRect();
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  } );
}

async function getFeatureBottomCenterScreenPos( page: Page ): Promise<{ x: number, y: number } | null> {
  return page.evaluate( () => {
    const mapEl = document.querySelector( "#observations-map" );
    if ( !mapEl ) return null;
    const scope = ( window as any ).angular.element( mapEl ).scope();
    if ( !scope || !scope.drawing || !scope.drawing.terraDraw || !scope.map ) return null;
    const snapshot = scope.drawing.terraDraw.getSnapshot();
    const feature = snapshot.find( ( f: any ) => f.id === scope.drawing.currentFeatureId );
    if ( !feature ) return null;
    const coords = feature.geometry.coordinates[0];
    let minLat = Infinity;
    let maxLat = -Infinity;
    let minLng = Infinity;
    let maxLng = -Infinity;
    for ( const c of coords ) {
      if ( c[1] < minLat ) minLat = c[1];
      if ( c[1] > maxLat ) maxLat = c[1];
      if ( c[0] < minLng ) minLng = c[0];
      if ( c[0] > maxLng ) maxLng = c[0];
    }
    const map = scope.map;
    const proj = map.getProjection();
    if ( !proj ) return null;
    const topRight = proj.fromLatLngToPoint( map.getBounds().getNorthEast() );
    const bottomLeft = proj.fromLatLngToPoint( map.getBounds().getSouthWest() );
    const scale = Math.pow( 2, map.getZoom() );
    const wp = proj.fromLatLngToPoint(
      new ( window as any ).google.maps.LatLng( minLat, ( minLng + maxLng ) / 2 )
    );
    const mapDiv = document.querySelector( "#map" ) as HTMLElement;
    const rect = mapDiv.getBoundingClientRect();
    return {
      x: rect.left + ( wp.x - bottomLeft.x ) * scale,
      y: rect.top + ( wp.y - topRight.y ) * scale
    };
  } );
}

async function waitForDragIconReady( page: Page ) {
  await expect( page.locator( 'img[src*="drag-icon"]' ) ).toBeVisible( { timeout: 15000 } );
  await expect.poll(
    async () => getDragIconScreenPos( page ),
    { timeout: 10000, intervals: [200, 400, 800] }
  ).not.toBeNull();
  await expect.poll(
    async () => getFeatureBottomCenterScreenPos( page ),
    { timeout: 10000, intervals: [200, 400, 800] }
  ).not.toBeNull();
}

async function dragIconBy( page: Page, dx: number, dy: number ): Promise<{
  before: { x: number, y: number }, target: { x: number, y: number }
}> {
  const before = await getDragIconScreenPos( page );
  expect( before ).not.toBeNull();
  const target = { x: before!.x + dx, y: before!.y + dy };
  await page.mouse.move( before!.x, before!.y );
  await page.mouse.down();
  await page.mouse.move( target.x, target.y, { steps: 20 } );
  await page.mouse.up();
  return { before: before!, target };
}

test.describe( "Observations map — shape drag icon", () => {
  test.use( { viewport: { width: 1440, height: 900 } } );

  test( "rectangle drag icon stays glued to shape after drag", async ( { page } ) => {
    await page.goto( `${envConfig.baseUrl}/observations?subview=map&nelat=50&nelng=-70&swlat=25&swlng=-125` );
    await waitForDragIconReady( page );

    const bottomBefore = await getFeatureBottomCenterScreenPos( page );
    const iconBefore = await getDragIconScreenPos( page );
    expect( Math.abs( ( iconBefore!.y - bottomBefore!.y ) - 20 ) ).toBeLessThan( 4 );

    const { target } = await dragIconBy( page, 80, -120 );

    await expect.poll( async () => {
      const p = await getDragIconScreenPos( page );
      if ( !p ) return null;
      return Math.hypot( p.x - target.x, p.y - target.y );
    }, { timeout: 5000 } ).toBeLessThan( 8 );

    const after = await getDragIconScreenPos( page );
    const bottomAfter = await getFeatureBottomCenterScreenPos( page );
    expect( Math.abs( ( after!.y - bottomAfter!.y ) - 20 ) ).toBeLessThan( 4 );
    expect( Math.abs( after!.x - target.x ) ).toBeLessThan( 8 );
    expect( Math.abs( after!.y - target.y ) ).toBeLessThan( 8 );
  } );

  test( "circle drag icon stays glued to shape after drag", async ( { page } ) => {
    await page.goto( `${envConfig.baseUrl}/observations?subview=map&lat=40&lng=-95&radius=500` );
    await waitForDragIconReady( page );

    const bottomBefore = await getFeatureBottomCenterScreenPos( page );
    const iconBefore = await getDragIconScreenPos( page );
    expect( Math.abs( ( iconBefore!.y - bottomBefore!.y ) - 20 ) ).toBeLessThan( 4 );

    const { target } = await dragIconBy( page, -60, -100 );

    await expect.poll( async () => {
      const p = await getDragIconScreenPos( page );
      if ( !p ) return null;
      return Math.hypot( p.x - target.x, p.y - target.y );
    }, { timeout: 5000 } ).toBeLessThan( 8 );

    const after = await getDragIconScreenPos( page );
    const bottomAfter = await getFeatureBottomCenterScreenPos( page );
    expect( Math.abs( ( after!.y - bottomAfter!.y ) - 20 ) ).toBeLessThan( 4 );
    expect( Math.abs( after!.x - target.x ) ).toBeLessThan( 8 );
    expect( Math.abs( after!.y - target.y ) ).toBeLessThan( 8 );
  } );
} );

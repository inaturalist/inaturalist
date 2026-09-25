import { test, expect } from "@playwright/test";
import {
  dots,
  expectActiveSlide,
  mountCarousel,
  rotation,
  slides,
  track
} from "../../helpers/carousel.helper";

test.describe( "carousel", ( ) => {
  test.beforeEach( async ( { page } ) => {
    await mountCarousel( page );
  } );

  test( "rotates to the next slide automatically", async ( { page } ) => {
    await expectActiveSlide( page, 0 );
    await expect( slides( page ).nth( 1 ) ).toHaveAttribute( "inert", "" );
    await expect( track( page ) ).toHaveAttribute( "aria-live", "off" );
    await page.clock.runFor( 5000 );
    await expectActiveSlide( page, 1 );
    await expect( slides( page ).nth( 0 ) ).toHaveAttribute( "inert", "" );
  } );

  test( "puts the rotation control first and skips hidden slides in the tab order", async ( { page } ) => {
    await page.locator( "#before" ).focus( );
    await page.keyboard.press( "Tab" );
    await expect( rotation( page ) ).toBeFocused( );
    for ( let i = 0; i < 3; i += 1 ) {
      await page.keyboard.press( "Tab" );
      await expect( dots( page ).nth( i ) ).toBeFocused( );
    }
    await page.keyboard.press( "Tab" );
    await expect( slides( page ).nth( 0 ).locator( "a.photo" ) ).toBeFocused( );
    await page.keyboard.press( "Tab" );
    await expect( slides( page ).nth( 0 ).locator( "a.title" ) ).toBeFocused( );
    await page.keyboard.press( "Tab" );
    await expect( page.locator( "#after" ) ).toBeFocused( );
  } );

  test( "stops rotating on keyboard focus until the rotation button restarts it", async ( { page } ) => {
    await page.locator( "#after" ).focus( );
    await page.keyboard.press( "Shift+Tab" );
    await page.keyboard.press( "Shift+Tab" );
    await expect( slides( page ).nth( 0 ).locator( "a.photo" ) ).toBeFocused( );
    await expect( rotation( page ) ).toHaveAccessibleName( "Start slide rotation" );
    await page.clock.runFor( 10000 );
    await expectActiveSlide( page, 0 );

    await rotation( page ).focus( );
    await page.keyboard.press( "Enter" );
    await expect( rotation( page ) ).toHaveAccessibleName( "Stop slide rotation" );
    await expect( rotation( page ) ).toBeFocused( );
    await page.clock.runFor( 5000 );
    await expectActiveSlide( page, 1 );
  } );

  test( "toggles rotation with a mouse click on the rotation button", async ( { page } ) => {
    await rotation( page ).click( );
    await expect( rotation( page ) ).toHaveAccessibleName( "Start slide rotation" );
    await expect( track( page ) ).toHaveAttribute( "aria-live", "polite" );

    await rotation( page ).click( );
    await expect( rotation( page ) ).toHaveAccessibleName( "Stop slide rotation" );
    await page.mouse.move( 0, 0 );
    await page.clock.runFor( 5000 );
    await expectActiveSlide( page, 1 );
  } );

  test( "jumps to a slide from its dot and stops rotating", async ( { page } ) => {
    await dots( page ).nth( 2 ).click( );
    await expectActiveSlide( page, 2 );
    await page.mouse.move( 0, 0 );
    await page.clock.runFor( 10000 );
    await expectActiveSlide( page, 2 );
    await expect( rotation( page ) ).toHaveAccessibleName( "Start slide rotation" );
  } );

  for ( const width of [360, 1200] ) {
    test( `shows the controls below the slides at ${width}px`, async ( { page } ) => {
      await page.setViewportSize( { width, height: 900 } );
      const trackBox = await track( page ).boundingBox( );
      const controls = await page.locator( ".Carousel-controls" ).boundingBox( );
      expect( controls?.y ).toBeGreaterThanOrEqual( ( trackBox?.y || 0 ) + ( trackBox?.height || 0 ) - 1 );
    } );
  }

  test( "gives every control a 44px target and a visible focus ring", async ( { page } ) => {
    const controls = [rotation( page ), ...[0, 1, 2].map( i => dots( page ).nth( i ) )];
    for ( const control of controls ) {
      const box = await control.boundingBox( );
      expect( box?.width ).toBeGreaterThanOrEqual( 44 );
      expect( box?.height ).toBeGreaterThanOrEqual( 44 );
    }
    await rotation( page ).focus( );
    await page.keyboard.press( "Tab" );
    expect( await dots( page ).nth( 0 ).evaluate( el => getComputedStyle( el ).outlineStyle ) ).not.toBe( "none" );
  } );
} );

test.describe( "carousel on touch screens", ( ) => {
  test.use( { viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true } );

  test( "follows a swipe and stops rotating", async ( { page } ) => {
    await mountCarousel( page );
    const box = await track( page ).boundingBox( );
    const y = Math.round( ( box?.y || 0 ) + ( box?.height || 0 ) / 2 );
    const startX = Math.round( ( box?.x || 0 ) + ( box?.width || 0 ) * 0.8 );
    const cdp = await page.context( ).newCDPSession( page );
    await cdp.send( "Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x: startX, y }] } );
    for ( let step = 1; step <= 10; step += 1 ) {
      await cdp.send( "Input.dispatchTouchEvent", {
        type: "touchMove",
        touchPoints: [{ x: startX - step * 25, y }]
      } );
    }
    await cdp.send( "Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] } );
    await expectActiveSlide( page, 1 );
    await expect( rotation( page ) ).toHaveAccessibleName( "Start slide rotation" );
  } );
} );

test.describe( "carousel with reduced motion", ( ) => {
  test( "does not rotate automatically", async ( { page } ) => {
    await page.emulateMedia( { reducedMotion: "reduce" } );
    await mountCarousel( page );
    await expect( rotation( page ) ).toHaveAccessibleName( "Start slide rotation" );
    await page.clock.runFor( 15000 );
    await expectActiveSlide( page, 0 );
  } );
} );

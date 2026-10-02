import { expect, test, Page } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";
import { carouselHtml } from "../../helpers/carousel.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

// Hero projects come from the Node API, absent under test, so the carousel markup is spliced in
async function injectCarousel( page: Page ): Promise<void> {
  await page.route( "**/projects", async route => {
    const response = await route.fetch( );
    const body = ( await response.text( ) ).replace(
      /(<div class=["']hero["']>)/,
      `$1${carouselHtml( 3 )}`
    );
    await route.fulfill( { response, body } );
  } );
}

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  await app( "add_test_group", { user_id: user.id, test_groups: "responsive-global" } );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

expectNoHorizontalOverflow( "/projects", {
  setup: injectCarousel,
  waitForSelector: "[data-carousel-root][data-state]"
} );

for ( const viewport of [{ width: 375, height: 800 }, { width: 1280, height: 900 }] ) {
  test.describe( `hero at ${viewport.width}px`, ( ) => {
    test.use( { viewport } );

    test.beforeEach( async ( { page } ) => {
      await injectCarousel( page );
      await page.goto( "/projects" );
      await page.waitForSelector( "[data-carousel-root][data-state]" );
    } );

    test( "icon fills the caption height", async ( { page } ) => {
      const caption = page.locator( ".Carousel-slide .project-caption h2" ).first( );
      const [link, img] = await Promise.all( [".icon", ".icon img"].map( s => caption.locator( s ).boundingBox( ) ) );
      const lineHeight = await caption.locator( ".title" ).evaluate( el => parseFloat( getComputedStyle( el ).lineHeight ) );
      expect( img ).toEqual( link );
      expect( img?.height ).toEqual( lineHeight );
    } );

    test( "controls are distinguishable from the about panel", async ( { page } ) => {
      const background = ( selector: string ) => page.locator( selector )
        .evaluate( el => getComputedStyle( el ).backgroundColor );
      expect( await background( ".Carousel-controls" ) ).not.toEqual( await background( "#about-projects" ) );
    } );

    test( "photo matches the recommended banner ratio", async ( { page } ) => {
      const box = await page.locator( ".Carousel-slide .photo" ).first( ).boundingBox( );
      expect( ( box?.width || 0 ) / ( box?.height || 1 ) ).toBeCloseTo( 760 / 320, 1 );
    } );
  } );
}

test.describe( "hero when the about panel is taller than the photo", ( ) => {
  test.use( { viewport: { width: 800, height: 900 } } );

  test( "photo stays within its slide", async ( { page } ) => {
    await injectCarousel( page );
    await page.goto( "/projects" );
    await page.waitForSelector( "[data-carousel-root][data-state]" );
    const track = await page.locator( ".Carousel-track" ).boundingBox( );
    const photo = await page.locator( ".Carousel-slide .photo" ).first( ).boundingBox( );
    expect( photo?.width ).toEqual( track?.width );
  } );
} );

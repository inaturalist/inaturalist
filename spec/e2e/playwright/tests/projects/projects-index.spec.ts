import { test, expect, Page } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { VIEWPORTS } from "../../../shared/breakpoints";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

// The index's project lists come from INatAPIService, which is not served in every
// environment; the hero layout assertions only mean something when it returned projects.
async function skipWithoutHeroProject( page: Page ): Promise<void> {
  const count = await page.locator( "#hero-container .hero-feature" ).count();
  test.skip( count === 0, "no featured project available from the API in this environment" );
}

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  await app( "add_test_group", { user_id: user.id, test_groups: "responsive-global" } );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

expectNoHorizontalOverflow( "/projects", { waitForSelector: "#hero-container" } );

test.describe( "Projects index hero", () => {
  test.beforeEach( async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xs );
    await page.goto( "/projects" );
    await page.locator( "#hero-container" ).waitFor();
  } );

  test( "renders a static hero instead of the Bootstrap carousel", async ( { page } ) => {
    await expect( page.locator( "#featured-carousel" ) ).toHaveCount( 0 );
    await expect( page.locator( ".carousel-indicators" ) ).toHaveCount( 0 );
    await expect( page.locator( "#hero-container .carousel" ) ).toHaveCount( 0 );
    await expect( page.locator( "#about-projects" ) ).toBeVisible();
  } );

  test( "stacks the about panel below the hero image", async ( { page } ) => {
    await skipWithoutHeroProject( page );

    const feature = await page.locator( "#hero-container .hero-feature" ).boundingBox();
    const about = await page.locator( "#about-projects" ).boundingBox();

    expect( about!.y ).toBeGreaterThanOrEqual( feature!.y + feature!.height - 1 );
  } );
} );

test.describe( "Projects index hero at the lg breakpoint", () => {
  test.beforeEach( async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.lg );
    await page.goto( "/projects" );
    await page.locator( "#hero-container" ).waitFor();
  } );

  test( "places the about panel beside the hero image", async ( { page } ) => {
    await skipWithoutHeroProject( page );

    const feature = await page.locator( "#hero-container .hero-feature" ).boundingBox();
    const about = await page.locator( "#about-projects" ).boundingBox();

    expect( about!.x ).toBeGreaterThanOrEqual( feature!.x + feature!.width - 1 );
  } );
} );

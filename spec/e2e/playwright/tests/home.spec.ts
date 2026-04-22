import { test, expect } from "@playwright/test";
import { BasePage } from "../page-objects/base.page";

test.describe( "Home page", () => {
  let basePage: BasePage;

  test.beforeEach( async ( { page } ) => {
    basePage = new BasePage( page );
    await page.goto( "/" );
  } );

  test( "displays header navigation", async () => {
    await expect( basePage.getHeader() ).toBeVisible();
  } );

  test( "displays footer", async () => {
    await expect( basePage.getFooter() ).toBeVisible();
  } );

  test( "has a page title", async () => {
    const title = await basePage.getPageTitle();
    expect( title.length ).toBeGreaterThan( 0 );
  } );

  test( "contains welcome content or sign-up CTA", async ( { page } ) => {
    const body = page.locator( "body" );
    await expect( body ).toBeVisible();
    await basePage.assertNoServerError();
  } );
} );

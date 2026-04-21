import { test, expect } from "@playwright/test";
import { BasePage } from "../page-objects/base.page";
import testData from "../fixtures/test-data.json";

test.describe( "Smoke tests @smoke", () => {
  let basePage: BasePage;

  test.beforeEach( async ( { page } ) => {
    basePage = new BasePage( page );
  } );

  test( "home page loads without errors", async ( { page } ) => {
    await page.goto( "/" );
    await basePage.assertNoServerError();
    const title = await basePage.getPageTitle();
    expect( title.length ).toBeGreaterThan( 0 );
    await expect( basePage.getHeader() ).toBeVisible();
  } );

  test( "observations index loads", async ( { page } ) => {
    await page.goto( "/observations" );
    await basePage.assertNoServerError();
    const title = await basePage.getPageTitle();
    expect( title.length ).toBeGreaterThan( 0 );
    await expect( basePage.getHeader() ).toBeVisible();
  } );

  test( "observation detail loads", async ( { page } ) => {
    await page.goto( `/observations/${testData.observations.knownId}` );
    await basePage.assertNoServerError();
    const title = await basePage.getPageTitle();
    expect( title.length ).toBeGreaterThan( 0 );
  } );

  test( "taxon page loads", async ( { page } ) => {
    await page.goto( `/taxa/${testData.taxa.knownId}` );
    await basePage.assertNoServerError();
    const title = await basePage.getPageTitle();
    expect( title.length ).toBeGreaterThan( 0 );
  } );

  test( "login page loads", async ( { page } ) => {
    await page.goto( "/login" );
    await basePage.assertNoServerError();
    const title = await basePage.getPageTitle();
    expect( title.length ).toBeGreaterThan( 0 );
    await expect( page.locator( "form.log-in" ) ).toBeVisible();
  } );
} );

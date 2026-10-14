import { test, expect } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";
import { VIEWPORTS } from "../../../shared/breakpoints";

const TEST_PASSWORD = "TestPass123!";
const INAT_GREEN = "rgb(116, 172, 0)";

let testEmail: string;
let testLogin: string;

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  testLogin = user.login as string;
  await app( "add_test_group", {
    user_id: user.id,
    test_groups: ["responsive-header", "responsive-global"]
  } );
  await Promise.all( Array.from( { length: 5 }, () => appMake( "create", "friendship", { user_id: user.id } ) ) );
  const favorites = await appMake( "create", "list", { user_id: user.id, title: "Favorites" } );
  await Promise.all( Array.from( { length: 5 }, () => appMake( "create", "listed_taxon", { list_id: favorites.id } ) ) );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

expectNoHorizontalOverflow( () => `/people/${testLogin}` );

test.describe( "subnav", () => {
  test( "uses the TabDropdown below the md breakpoint", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xs );
    await page.goto( `/people/${testLogin}` );
    const toggle = page.locator( "#UserSubnavTabDropdown button[aria-expanded]" );
    await expect( toggle ).toBeVisible();
    await expect( toggle ).toHaveText( /Profile/ );
    await expect( page.locator( ".nav-tabs.user-subnav" ) ).toBeHidden();

    await toggle.click();
    await expect( toggle ).toHaveAttribute( "aria-expanded", "true" );
    await page.locator( "#UserSubnavTabDropdown" ).getByRole( "link", { name: "Calendar" } ).click();
    await page.waitForURL( `**/calendar/${testLogin}**` );
  } );

  test( "renders the redesigned TabDropdown toggle", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xs );
    await page.goto( `/people/${testLogin}` );
    const toggle = page.locator( "#UserSubnavTabDropdown button[aria-expanded]" );
    await expect( toggle ).toBeVisible();
    const style = await toggle.evaluate( el => {
      const chevron = el.querySelector( ".fa-chevron-down" ) as Element;
      return {
        width: el.getBoundingClientRect().width,
        fontSize: getComputedStyle( el ).fontSize,
        chevronColor: getComputedStyle( chevron ).color
      };
    } );
    const viewportWidth = await page.evaluate( () => document.documentElement.clientWidth );
    expect( style.width ).toBeCloseTo( viewportWidth, 0 );
    expect( style.fontSize ).toBe( "24px" );
    expect( style.chevronColor ).toBe( INAT_GREEN );
  } );

  ( ["md", "lg"] as const ).forEach( name => {
    test( `uses the tabs at the ${name} breakpoint`, async ( { page } ) => {
      await page.setViewportSize( VIEWPORTS[name] );
      await page.goto( `/people/${testLogin}` );
      await expect( page.locator( ".nav-tabs.user-subnav" ) ).toBeVisible();
      await expect( page.locator( "#UserSubnavTabDropdown button[aria-expanded]" ) ).toBeHidden();
    } );
  } );
} );

test.describe( "layout", () => {
  test( "puts the sidebar beside the main column at lg", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.lg );
    await page.goto( `/people/${testLogin}` );
    const sidebar = await page.locator( ".profile-sidebar" ).boundingBox();
    const main = await page.locator( ".profile-main" ).boundingBox();
    expect( main!.x ).toBeGreaterThan( sidebar!.x + sidebar!.width - 1 );
    expect( main!.y ).toBeCloseTo( sidebar!.y, 0 );
  } );

  test( "stacks the sidebar above the main column at xs", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xs );
    await page.goto( `/people/${testLogin}` );
    const sidebar = await page.locator( ".profile-sidebar" ).boundingBox();
    const main = await page.locator( ".profile-main" ).boundingBox();
    expect( main!.y ).toBeGreaterThanOrEqual( sidebar!.y + sidebar!.height - 1 );
  } );

  test( "lays followees and favorites out in grids", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.lg );
    await page.goto( `/people/${testLogin}` );
    await expect( page.locator( ".profile-grid .profile-grid-item .media" ).first() ).toBeVisible();
    await expect( page.locator( "#favorites .profile-grid .profile-grid-item .thumbnail" ).first() ).toBeVisible();
  } );
} );

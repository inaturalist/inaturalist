import { test, expect, Page } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { VIEWPORTS } from "../../../shared/breakpoints";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

async function menuLabels( page: Page ): Promise<{ mainnav: string[]; hamburger: string[] }> {
  return page.evaluate( () => {
    const norm = ( s: string | null ) => ( s || "" ).replace( /\s+/g, " " ).trim();

    const mainnav = Array.from(
      document.querySelectorAll( "#mainnav > li.navtab" )
    ).map( li => {
      const toggle = li.querySelector( ":scope > .dropdown > .dropdown-toggle" );
      return norm( ( toggle || li ).textContent );
    } ).filter( Boolean );

    const hamburger = Array.from(
      document.querySelectorAll( "#narrow-menu .dropdown-menu > li" )
    ).map( li => {
      const submenuAnchor = li.matches( ".submenu" ) ? li.querySelector( ":scope > a" ) : null;
      return norm( ( submenuAnchor || li ).textContent );
    } ).filter( Boolean );

    return { mainnav, hamburger };
  } );
}

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  await app( "add_test_group", { user_id: user.id, test_groups: "responsive-header" } );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

test.describe( "Header search bar (desktop)", () => {
  test.beforeEach( async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xl );
    await page.goto( "/" );
    await page.locator( "#headersearch" ).waitFor();
  } );

  test( "opens and closes via the show/hide buttons", async ( { page } ) => {
    const search = page.locator( "#headersearch" );
    const header = page.locator( "#header" );

    // Normalize to the closed state regardless of the session default.
    if ( await search.evaluate( el => el.classList.contains( "open" ) ) ) {
      await page.locator( "#header .hide-btn" ).click();
    }
    await expect( search ).not.toHaveClass( /\bopen\b/ );

    // Open
    await page.locator( "#header .show-btn" ).click();
    await expect( search ).toHaveClass( /\bopen\b/ );
    await expect( header ).toHaveClass( /\bsearch-open\b/ );
    await expect( page.locator( "#headersearch input" ) ).toBeFocused();

    // Close
    await page.locator( "#header .hide-btn" ).click();
    await expect( search ).not.toHaveClass( /\bopen\b/ );
    await expect( header ).not.toHaveClass( /\bsearch-open\b/ );
  } );
} );

test.describe( "Header navigation parity (desktop)", () => {
  test.beforeEach( async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xl );
    await page.goto( "/" );
    await page.locator( "#mainnav" ).waitFor();
  } );

  test( "every #mainnav item also exists in the hamburger menu", async ( { page } ) => {
    const { mainnav, hamburger } = await menuLabels( page );

    expect( mainnav.length ).toBeGreaterThan( 0 );
    for ( const label of mainnav ) {
      expect(
        hamburger,
        `"${label}" from #mainnav should also appear in the #narrow-menu hamburger menu`
      ).toContain( label );
    }

    for ( const label of hamburger ) {
      // Search is not in the mainnav when search bar active
      if ( label !== "Search" ) {
      expect(
          mainnav,
          `"${label}" from #narrow-menu hamburger menu should also appear in the #mainnav`
        ).toContain( label );
      }
    }
  } );
} );

expectNoHorizontalOverflow( "/" );

test.describe( "Header at the sm breakpoint (logged in)", () => {
  test.beforeEach( async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.sm );
    await page.goto( "/" );
    await page.locator( "#header .add-obs" ).waitFor();
  } );

  test( "upload button text is not visible", async ( { page } ) => {
    await expect( page.locator( "#header .add-obs .btn-inat span" ) ).toBeHidden();
  } );
} );

test.describe( "Header at the md breakpoint (logged in)", () => {
  test.beforeEach( async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.md );
    await page.goto( "/" );
    await page.locator( "#header" ).waitFor();
  } );

  test( "the navtabs collapse into the hamburger menu while the search bar stays", async ( { page } ) => {
    // The desktop navtabs collapse into the hamburger menu...
    await expect( page.locator( "#mainnav" ) ).toBeHidden();
    await expect( page.locator( "#narrow-menu" ) ).toBeVisible();

    // ...but the search bar still displays in the header.
    await expect( page.locator( "#headersearch" ) ).toBeVisible();
  } );
} );

test.describe( "Header at the lg breakpoint (logged in)", () => {
  test.beforeEach( async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.lg );
    await page.goto( "/" );
    await page.locator( "#header .add-obs" ).waitFor();
  } );

  test( "upload button text is visible", async ( { page } ) => {
    await expect( page.locator( "#header .add-obs .btn-inat span" ) ).toBeVisible();
  } );
} );

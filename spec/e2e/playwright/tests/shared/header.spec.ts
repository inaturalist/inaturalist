import { test, expect, Page } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { BreakpointName, VIEWPORTS } from "../../../shared/breakpoints";
import { expectNoHorizontalOverflow, expectWithinViewport } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

type HeaderItem = "narrow-menu" | "logonav" | "headersearch" | "mainnav"
  | "add-obs" | "messagenav" | "updatesnav" | "user menutab";

const HEADER_ITEMS: Record<HeaderItem, string> = {
  "narrow-menu": "#header #narrow-menu",
  logonav: "#header #logonav",
  headersearch: "#header #headersearch",
  mainnav: "#header #mainnav",
  "add-obs": "#header .add-obs",
  messagenav: "#header #messagesnav",
  updatesnav: "#header #updatesnav",
  "user menutab": "#header .navtab.user.menutab"
};

const ALWAYS: HeaderItem[] = ["logonav", "messagenav", "updatesnav", "user menutab"];

// #narrow-menu and #mainnav are alternatives, never both
const RESPONSIVE_INVENTORY: Record<BreakpointName, HeaderItem[]> = {
  xxs: ["narrow-menu", ...ALWAYS],
  xs: ["narrow-menu", ...ALWAYS, "add-obs"],
  sm: ["narrow-menu", ...ALWAYS, "add-obs"],
  md: ["narrow-menu", ...ALWAYS, "add-obs", "headersearch"],
  lg: ["narrow-menu", ...ALWAYS, "add-obs", "headersearch"],
  xl: [...ALWAYS, "add-obs", "headersearch", "mainnav"],
  xxl: [...ALWAYS, "add-obs", "headersearch", "mainnav"]
};

const LEGACY_INVENTORY: HeaderItem[] = [
  "logonav", "headersearch", "mainnav", "add-obs", "messagenav", "updatesnav", "user menutab"
];

async function expectHeaderItems( page: Page, visible: HeaderItem[] ): Promise<void> {
  const entries = Object.entries( HEADER_ITEMS ) as [HeaderItem, string][];

  for ( const [item, selector] of entries ) {
    const locator = page.locator( selector );
    const shouldShow = visible.includes( item );
    await expect(
      locator,
      `${item} should be ${shouldShow ? "visible" : "hidden"}`
    )[shouldShow ? "toBeVisible" : "toBeHidden"]( );
  }
}

async function gotoHeader( page: Page, breakpoint: BreakpointName ): Promise<void> {
  await page.setViewportSize( VIEWPORTS[breakpoint] );
  await page.goto( "/" );
  await page.locator( "#header" ).waitFor( );
}

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

expectNoHorizontalOverflow( "/", {
  setup: page => login( page, testEmail, TEST_PASSWORD )
} );

test.describe( "Header search bar (desktop)", () => {
  test.beforeEach( async ( { page } ) => {
    await login( page, testEmail, TEST_PASSWORD );
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
    await login( page, testEmail, TEST_PASSWORD );
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

test.describe( "Header at the sm breakpoint (logged in)", () => {
  test.beforeEach( async ( { page } ) => {
    await login( page, testEmail, TEST_PASSWORD );
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
    await login( page, testEmail, TEST_PASSWORD );
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

  test( "upload button text is visible", async ( { page } ) => {
    await expect( page.locator( "#header .add-obs .btn-inat span" ) ).toBeVisible();
  } );
} );

test.describe( "Header at the lg breakpoint (logged in)", () => {
  test.beforeEach( async ( { page } ) => {
    await login( page, testEmail, TEST_PASSWORD );
    await page.setViewportSize( VIEWPORTS.lg );
    await page.goto( "/" );
    await page.locator( "#header .add-obs" ).waitFor();
  } );

  test( "upload button text is visible", async ( { page } ) => {
    await expect( page.locator( "#header .add-obs .btn-inat span" ) ).toBeVisible();
  } );
} );

test.describe( "Header with large notification counts", () => {
  const setCounts = ( page: Page, count: number ) => page.evaluate( c => {
    ( window as any ).setUpdatesCount( c, { skipAnimation: true } );
    ( window as any ).setMessagesCount( c, { skipAnimation: true } );
  }, count );

  test.beforeEach( async ( { page } ) => {
    await login( page, testEmail, TEST_PASSWORD );
  } );

  test( "keeps the upload button at the xs breakpoint", async ( { page } ) => {
    await gotoHeader( page, "xs" );
    await setCounts( page, 99999 );

    await expect( page.locator( "#header .add-obs" ) ).toBeVisible();
    await expectWithinViewport( page, "xs breakpoint" );
  } );

  test( "caps the badge at three digits and keeps it at the xs breakpoint", async ( { page } ) => {
    await gotoHeader( page, "xs" );
    await setCounts( page, 99999 );

    await expect( page.locator( "#header #updatesnav .count" ) ).toHaveText( "999+" );
    await expect( page.locator( "#header #messagesnav .count" ) ).toBeVisible();
  } );

  test( "drops the badges below 380px once either passes two digits", async ( { page } ) => {
    await gotoHeader( page, "xxs" );

    await setCounts( page, 99 );
    await expect( page.locator( "#header #updatesnav .count" ) ).toBeVisible();

    await setCounts( page, 100 );
    await expect( page.locator( "#header #updatesnav .count" ) ).toBeHidden();
    await expect( page.locator( "#header #messagesnav .count" ) ).toBeHidden();

    // The icons take over the space the badges gave up, so they stay easy to hit.
    const padding = await page.locator( "#header #updatesnav > *" )
      .evaluate( el => getComputedStyle( el ).paddingInlineStart );
    expect( padding ).toBe( "9px" );

    await expectWithinViewport( page, "xxs breakpoint" );
  } );

  test( "offers the upload link in the user menu at the xxs breakpoint", async ( { page } ) => {
    await gotoHeader( page, "xxs" );
    await setCounts( page, 99999 );

    await expect( page.locator( "#header .add-obs" ) ).toBeHidden();

    // The user menu keeps offering the upload link, so nothing becomes unreachable.
    const menuItemDisplay = await page.locator(
      "#header .dropdown-menu .add-obs-menu-item"
    ).evaluate( el => getComputedStyle( el ).display );
    expect( menuItemDisplay ).not.toBe( "none" );

    await expectWithinViewport( page, "xxs breakpoint" );
  } );
} );

test.describe( "Header item inventory (responsive-global)", () => {
  let responsiveEmail: string;

  test.beforeAll( async () => {
    const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
    responsiveEmail = user.email as string;
    await app( "add_test_group", { user_id: user.id, test_groups: "responsive-global" } );
  } );

  test.beforeEach( async ( { page } ) => {
    await login( page, responsiveEmail, TEST_PASSWORD );
  } );

  ( Object.entries( RESPONSIVE_INVENTORY ) as [BreakpointName, HeaderItem[]][] ).forEach(
    ( [breakpoint, items] ) => {
      test( `shows ${items.join( ", " )} at the ${breakpoint} breakpoint (${VIEWPORTS[breakpoint].width}px)`, async ( { page } ) => {
        await gotoHeader( page, breakpoint );

        await expectHeaderItems( page, items );
      } );
    }
  );
} );

test.describe( "Header item inventory (no test group)", () => {
  let legacyEmail: string;

  test.beforeAll( async () => {
    const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
    legacyEmail = user.email as string;
  } );

  test.beforeEach( async ( { page } ) => {
    await login( page, legacyEmail, TEST_PASSWORD );
  } );

  test( "shows every header item except the hamburger menu at the md breakpoint", async ( { page } ) => {
    await gotoHeader( page, "md" );

    await expectHeaderItems( page, LEGACY_INVENTORY );
  } );
} );

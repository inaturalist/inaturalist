import { test, expect, Page } from "@playwright/test";
import { BREAKPOINTS, BreakpointName, VIEWPORTS } from "../../shared/breakpoints";

async function measureHorizontalOverflow(
  page: Page
): Promise<{ bodyWidth: number; viewportWidth: number }> {
  return page.evaluate( () => ( {
    bodyWidth: document.body.scrollWidth,
    viewportWidth: window.innerWidth
  } ) );
}

interface ResponsiveCheckOptions {
  // Selector to wait for after navigation before measuring/capturing.
  waitForSelector?: string;
  // Set false to skip the visual-regression screenshot step.
  screenshot?: boolean;
  // Extra page-specific selectors to mask in screenshots (dynamic content
  // that legitimately differs between runs, e.g. async-loaded feeds).
  mask?: string[];
  // Base name for the screenshot files; defaults to a slug derived from `path`.
  label?: string;
}

// The header user menu (avatar, login, message/update counts) differs between
// runs because each test provisions a fresh, randomly-named user. Mask it on
// every page so it never triggers a false visual diff.
const SHARED_DYNAMIC_MASKS = ["#usernav"];

function labelForPath( path: string ): string {
  if ( path === "/" ) {
    return "root";
  }
  return path.replace( /^\/+/, "" ).replace( /[^a-z0-9]+/gi, "-" ) || "root";
}

export function expectNoHorizontalOverflow(
  path = "/",
  options: ResponsiveCheckOptions = {}
): void {
  const label = options.label || labelForPath( path );

  test.describe( "no horizontal overflow", () => {
    for ( const name of Object.keys( VIEWPORTS ) as BreakpointName[] ) {
      const viewport = VIEWPORTS[name];

      test( `the document body does not overflow the viewport at the ${name} breakpoint (${viewport.width}px)`, async ( { page } ) => {
        await page.setViewportSize( viewport );
        await page.goto( path );
        await page.locator( options.waitForSelector || "#header" ).waitFor();

        const { bodyWidth, viewportWidth } = await measureHorizontalOverflow( page );

        expect( viewportWidth ).toBeGreaterThanOrEqual( BREAKPOINTS[name].minWidth );

        expect(
          bodyWidth,
          `body (${bodyWidth}px) overflows the ${name} viewport (${viewportWidth}px)`
        ).toBeLessThanOrEqual( viewportWidth + 1 );

        // Visual-regression step: capture a full-page snapshot at this
        // breakpoint and compare it against the committed baseline.
        // currently only used for local development
        if ( options.screenshot !== false ) {
          const masks = [...SHARED_DYNAMIC_MASKS, ...( options.mask || [] )]
            .map( selector => page.locator( selector ) );

          await expect( page ).toHaveScreenshot( `${label}-${name}.png`, {
            fullPage: true,
            mask: masks
          } );
        }
      } );
    }
  } );
}

import { test, expect, Page } from "@playwright/test";
import { BREAKPOINTS, BreakpointName, VIEWPORTS } from "../../shared/breakpoints";

/**
 * Measure how far the document body extends horizontally versus the active
 * browser viewport. `bodyWidth` uses `scrollWidth` so content that spills past
 * the body's own box (the signature of horizontal overflow) is counted, and is
 * compared against `window.innerWidth` — the viewport width the user actually
 * sees, scrollbar excluded.
 */
async function measureHorizontalOverflow(
  page: Page
): Promise<{ bodyWidth: number; viewportWidth: number }> {
  return page.evaluate( () => ( {
    bodyWidth: document.body.scrollWidth,
    viewportWidth: window.innerWidth
  } ) );
}

/**
 * Assert that the document body does not overflow the viewport horizontally at
 * every responsive breakpoint. For each tier this sets the representative
 * viewport, (re)loads `path`, and checks that the body is no wider than the
 * viewport. A 1px tolerance absorbs sub-pixel rounding.
 *
 * Use this in a spec's top level (it registers one `test` per breakpoint):
 *
 *   import { expectNoHorizontalOverflowAtEveryBreakpoint } from "../../helpers/overflow.helper";
 *   expectNoHorizontalOverflowAtEveryBreakpoint( "/" );
 */
export function expectNoHorizontalOverflowAtEveryBreakpoint(
  path = "/",
  options: { waitForSelector?: string } = {}
): void {
  test.describe( "no horizontal overflow", () => {
    for ( const name of Object.keys( VIEWPORTS ) as BreakpointName[] ) {
      const viewport = VIEWPORTS[name];

      test( `the document body does not overflow the viewport at the ${name} breakpoint (${viewport.width}px)`, async ( { page } ) => {
        await page.setViewportSize( viewport );
        await page.goto( path );
        await page.locator( options.waitForSelector || "#header" ).waitFor();

        const { bodyWidth, viewportWidth } = await measureHorizontalOverflow( page );

        // Sanity-check the viewport actually matches the tier we set, so a
        // failure points at overflow rather than a missized window.
        expect( viewportWidth ).toBeGreaterThanOrEqual( BREAKPOINTS[name].minWidth );

        // Allow 1px for sub-pixel rounding.
        expect(
          bodyWidth,
          `body (${bodyWidth}px) overflows the ${name} viewport (${viewportWidth}px)`
        ).toBeLessThanOrEqual( viewportWidth + 1 );
      } );
    }
  } );
}

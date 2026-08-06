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

export function expectNoHorizontalOverflow(
  path: string | ( () => string ) = "/",
  options: { waitForSelector?: string; setup?: ( page: Page ) => Promise<void> } = {}
): void {
  test.describe( "no horizontal overflow", () => {
    for ( const name of Object.keys( VIEWPORTS ) as BreakpointName[] ) {
      const viewport = VIEWPORTS[name];

      test( `the document body does not overflow the viewport at the ${name} breakpoint (${viewport.width}px)`, async ( { page } ) => {
        await page.setViewportSize( viewport );
        if ( options.setup ) { await options.setup( page ); }
        await page.goto( typeof path === "function" ? path() : path );
        await page.locator( options.waitForSelector || "#header" ).first().waitFor();

        const { bodyWidth, viewportWidth } = await measureHorizontalOverflow( page );

        expect( viewportWidth ).toBeGreaterThanOrEqual( BREAKPOINTS[name].minWidth );

        expect(
          bodyWidth,
          `body (${bodyWidth}px) overflows the ${name} viewport (${viewportWidth}px)`
        ).toBeLessThanOrEqual( viewportWidth + 1 );
      } );
    }
  } );
}

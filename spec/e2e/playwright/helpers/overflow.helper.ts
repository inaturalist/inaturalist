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

export async function expectWithinViewport( page: Page, context?: string ): Promise<void> {
  const { bodyWidth, viewportWidth } = await measureHorizontalOverflow( page );

  expect(
    bodyWidth,
    `body (${bodyWidth}px) overflows the ${context || "current"} viewport (${viewportWidth}px)`
  ).toBeLessThanOrEqual( viewportWidth + 1 );
}

export function expectNoHorizontalOverflow(
  path: string | ( () => string ) = "/",
  options: {
    waitForSelector?: string;
    setup?: ( page: Page ) => Promise<void>;
    viewports?: BreakpointName[];
  } = {}
): void {
  test.describe( "no horizontal overflow", () => {
    const viewports = options.viewports || Object.keys( VIEWPORTS ) as BreakpointName[];

    viewports.forEach( name => {
      const viewport = VIEWPORTS[name];

      test( `the document body does not overflow the viewport at the ${name} breakpoint (${viewport.width}px)`, async ( { page } ) => {
        await page.setViewportSize( viewport );
        if ( options.setup ) { await options.setup( page ); }
        await page.goto( typeof path === "function" ? path() : path );
        await page.locator( options.waitForSelector || "#header" ).first().waitFor();

        const { viewportWidth } = await measureHorizontalOverflow( page );
        expect( viewportWidth ).toBeGreaterThanOrEqual( BREAKPOINTS[name].minWidth );

        await expectWithinViewport( page, `${name} breakpoint` );
      } );
    } );
  } );
}

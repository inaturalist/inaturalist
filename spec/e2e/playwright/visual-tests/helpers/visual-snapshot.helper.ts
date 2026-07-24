import { test, expect, Page, Locator } from "@playwright/test";
import { VIEWPORTS, BreakpointName } from "../../../shared/breakpoints";

type MaybeThunk<T> = T | ( () => T );

// Paths often depend on ids created in beforeAll, which don't exist when the
// helper runs at collection time — allow a thunk resolved at test runtime.
const unwrap = <T>( value: MaybeThunk<T> ): T => (
  typeof value === "function" ? ( value as () => T )() : value
);

// react-lazyload sections (e.g. the taxon Highlights discoveries/wanted
// carousels) only fetch once scrolled into view. Step through the full page so
// they mount, then return to the top before capturing.
async function triggerLazyLoad( page: Page ): Promise<void> {
  await page.evaluate( async () => {
    const step = window.innerHeight;
    for ( let y = 0; y < document.body.scrollHeight; y += step ) {
      window.scrollTo( 0, y );
      await new Promise( resolve => { setTimeout( resolve, 100 ); } );
    }
    window.scrollTo( 0, 0 );
  } );
}

export interface VisualSnapshotOptions {
  waitForSelector?: string;
  setup?: ( page: Page ) => Promise<void>;
  mask?: ( page: Page ) => Locator[];
}

export function expectVisualSnapshots(
  namePrefix: string,
  path: MaybeThunk<string>,
  options: VisualSnapshotOptions = {}
): void {
  test.describe( "visual snapshots", () => {
    for ( const name of Object.keys( VIEWPORTS ) as BreakpointName[] ) {
      const viewport = VIEWPORTS[name];
      test( `${namePrefix} at ${name} (${viewport.width}px)`, async ( { page } ) => {
        if ( options.setup ) await options.setup( page );
        await page.setViewportSize( viewport );
        await page.goto( unwrap( path ) );
        await page.locator( options.waitForSelector ?? "#header" ).waitFor( { timeout: 15_000 } );
        await triggerLazyLoad( page );
        // No fixed wait: waitForSelector above gates the key content, and
        // toHaveScreenshot polls until two consecutive frames match (with
        // animations disabled), absorbing lazy-loaded content as it settles.
        await expect( page ).toHaveScreenshot( `${namePrefix}-${name}.png`, {
          fullPage: true,
          mask: options.mask?.( page ) ?? []
        } );
      } );
    }
  } );
}

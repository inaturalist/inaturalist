import { test, expect, Page, Locator } from "@playwright/test";
import { VIEWPORTS, BreakpointName } from "../../../shared/breakpoints";

type MaybeThunk<T> = T | ( () => T );

// Paths often depend on ids created in beforeAll, which don't exist when the
// helper runs at collection time — allow a thunk resolved at test runtime.
const unwrap = <T>( value: MaybeThunk<T> ): T => (
  typeof value === "function" ? ( value as () => T )() : value
);

// Lazy sections only mount once scrolled into view, and some (e.g. the obs-show
// Data Quality Assessment, wrapped in react-lazy-load) mount ONLY when actually
// in the viewport. As each mounts it adds height, shifting the bottom, so a
// single pass can miss the lowest sections. Scroll to the bottom repeatedly
// until the page height stabilizes, then return to the top. Sections stay
// mounted once visible, so the final capture (scrolled to top) includes them.
async function triggerLazyLoad( page: Page ): Promise<void> {
  await page.evaluate( async () => {
    const delay = ( ms: number ) => new Promise( resolve => { setTimeout( resolve, ms ); } );
    let previousHeight = -1;
    for ( let pass = 0; pass < 10 && document.body.scrollHeight !== previousHeight; pass += 1 ) {
      previousHeight = document.body.scrollHeight;
      for ( let y = 0; y <= previousHeight; y += window.innerHeight ) {
        window.scrollTo( 0, y );
        await delay( 60 );
      }
      window.scrollTo( 0, document.body.scrollHeight );
      await delay( 150 );
    }
    window.scrollTo( 0, 0 );
  } );
}

export interface VisualSnapshotOptions {
  waitForSelector?: string;
  setup?: ( page: Page ) => Promise<void>;
  mask?: ( page: Page ) => Locator[];
  // Restrict to a subset of breakpoints. Defaults to every breakpoint.
  breakpoints?: BreakpointName[];
}

export function expectVisualSnapshots(
  namePrefix: string,
  path: MaybeThunk<string>,
  options: VisualSnapshotOptions = {}
): void {
  test.describe( "visual snapshots", () => {
    const names = options.breakpoints ?? ( Object.keys( VIEWPORTS ) as BreakpointName[] );
    for ( const name of names ) {
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

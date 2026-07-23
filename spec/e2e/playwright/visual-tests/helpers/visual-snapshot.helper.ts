import { test, expect, Page, Locator } from "@playwright/test";
import { VIEWPORTS, BreakpointName } from "../../../shared/breakpoints";

type MaybeThunk<T> = T | ( () => T );

// Paths often depend on ids created in beforeAll, which don't exist when the
// helper runs at collection time — allow a thunk resolved at test runtime.
const unwrap = <T>( value: MaybeThunk<T> ): T => (
  typeof value === "function" ? ( value as () => T )() : value
);

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
        await page.waitForTimeout( 10_000 ); // wait for any animations to finish
        await expect( page ).toHaveScreenshot( `${namePrefix}-${name}.png`, {
          fullPage: true,
          mask: options.mask?.( page ) ?? []
        } );
      } );
    }
  } );
}

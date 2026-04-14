import { Page } from "@playwright/test";

/**
 * Waits for the React bundle to finish mounting.
 *
 * iNaturalist pages render a #initial-loading spinner inside #app.
 * When the React component tree mounts, the spinner is removed.
 * For non-React pages the #app or #initial-loading element may not exist,
 * so we treat that as "already loaded".
 */
export async function waitForReactMount( page: Page, timeout = 30_000 ): Promise<void> {
  const app = page.locator( "#app" );
  const appExists = await app.count() > 0;
  if ( !appExists ) {
    return;
  }

  const spinner = app.locator( "#initial-loading" );
  const spinnerExists = await spinner.count() > 0;
  if ( !spinnerExists ) {
    return;
  }

  await spinner.waitFor( { state: "detached", timeout } );
}

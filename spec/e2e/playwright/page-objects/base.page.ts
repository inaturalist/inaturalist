import { Page } from "@playwright/test";

export class BasePage {
  readonly page: Page;

  constructor( page: Page ) {
    this.page = page;
  }

  async goto( path: string ): Promise<void> {
    await this.page.goto( path );
  }

  /**
   * Waits for the React bundle to finish mounting.
   *
   * iNaturalist pages render a #initial-loading spinner inside #app.
   * When the React component tree mounts, the spinner is removed. For
   * non-React pages #app or #initial-loading may not exist; in that case
   * we treat the page as already loaded.
   */
  async waitForReactMount( timeout = 30_000 ): Promise<void> {
    const app = this.page.locator( "#app" );
    if ( await app.count() === 0 ) return;

    const spinner = app.locator( "#initial-loading" );
    if ( await spinner.count() === 0 ) return;

    await spinner.waitFor( { state: "detached", timeout } );
  }

  async isLoggedIn(): Promise<boolean> {
    return this.page.evaluate( () =>
      typeof ( window as any ).CURRENT_USER !== "undefined"
        && ( window as any ).CURRENT_USER !== null
    );
  }
}

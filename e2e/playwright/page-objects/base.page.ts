import { Page, Locator, expect } from "@playwright/test";
import { waitForReactMount } from "../helpers/wait-for-react.helper";

export class BasePage {
  readonly page: Page;

  constructor( page: Page ) {
    this.page = page;
  }

  async goto( path: string ): Promise<void> {
    await this.page.goto( path );
  }

  async waitForReactMount( timeout?: number ): Promise<void> {
    await waitForReactMount( this.page, timeout );
  }

  async waitForPageReady(): Promise<void> {
    await this.page.waitForLoadState( "domcontentloaded" );
  }

  getHeader(): Locator {
    return this.page.locator( "#header.bootstrap" );
  }

  getFooter(): Locator {
    return this.page.locator( "#footer.bootstrap" );
  }

  async isLoggedIn(): Promise<boolean> {
    const currentUser = await this.page.evaluate( () => {
      return typeof ( window as any ).CURRENT_USER !== "undefined"
        && ( window as any ).CURRENT_USER !== null;
    } );
    return currentUser;
  }

  async getPageTitle(): Promise<string> {
    return this.page.title();
  }

  async assertNoServerError(): Promise<void> {
    const bodyText = await this.page.locator( "body" ).textContent();
    expect( bodyText ).not.toContain( "500 Internal Server Error" );
    expect( bodyText ).not.toContain( "We're sorry, but something went wrong" );
  }
}

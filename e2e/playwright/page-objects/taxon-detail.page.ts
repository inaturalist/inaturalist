import { Page, Locator } from "@playwright/test";
import { BasePage } from "./base.page";

export class TaxonDetailPage extends BasePage {
  constructor( page: Page ) {
    super( page );
  }

  async goto( id: number | string ): Promise<void> {
    await super.goto( `/taxa/${id}` );
    await this.waitForReactMount();
  }

  getTaxonName(): Locator {
    return this.page.locator( ".TaxonHeader, .taxon-name, h1" ).first();
  }

  getPhotos(): Locator {
    return this.page.locator( ".PhotoBrowser, .TaxonPhotos, .photo-container" ).first();
  }

  getTaxonomyBreadcrumb(): Locator {
    return this.page.locator( ".TaxonomyTab, .taxonomy, .breadcrumb" ).first();
  }

  getTabs(): Locator {
    return this.page.locator( ".nav-tabs, .Tabs, [role='tablist']" ).first();
  }

  getMap(): Locator {
    return this.page.locator( ".TaxonMap, .map-container, [class*='map']" ).first();
  }
}

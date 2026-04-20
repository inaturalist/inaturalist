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
    return this.page.locator( "#TaxonHeader h1" ).first();
  }

  getPhotos(): Locator {
    return this.page.locator( "#TaxonDetail .PhotoPreview" ).first();
  }

  getTaxonomyBreadcrumb(): Locator {
    return this.page.locator( "#TaxonDetail .TaxonCrumbs" ).first();
  }

  getTabs(): Locator {
    return this.page.locator( "#main-tabs" ).first();
  }

  getMap(): Locator {
    return this.page.locator( "#TaxonDetail .TaxonMap" ).first();
  }
}

import { Page, Locator } from "@playwright/test";
import { BasePage } from "./base.page";

export class ObservationDetailPage extends BasePage {
  constructor( page: Page ) {
    super( page );
  }

  async goto( id: number | string ): Promise<void> {
    await super.goto( `/observations/${id}` );
    await this.waitForReactMount();
  }

  getPhoto(): Locator {
    return this.page.locator( ".image-gallery, .PhotoBrowser, .photo-container" ).first();
  }

  getTaxonName(): Locator {
    return this.page.locator( ".TaxonHeader, .taxon-name, .community-taxon" ).first();
  }

  getObserver(): Locator {
    return this.page.locator( ".observer, .user-image, .ObserverInfo" ).first();
  }

  getMap(): Locator {
    return this.page.locator( ".observation-map, .MapDetails, [class*='map']" ).first();
  }

  getActivitySection(): Locator {
    return this.page.locator( ".Activity, .activity, .comments-ids" ).first();
  }
}

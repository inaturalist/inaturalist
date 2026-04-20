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
    return this.page.locator( "#ObservationShow .photos_column" ).first();
  }

  getTaxonName(): Locator {
    return this.page.locator( "#ObservationShow .ObservationTitle" ).first();
  }

  getObserver(): Locator {
    return this.page.locator( "#ObservationShow .user_info" ).first();
  }

  getMap(): Locator {
    return this.page.locator( "#ObservationShow .Map" ).first();
  }

  getActivitySection(): Locator {
    return this.page.locator( "#ObservationShow .Activity" ).first();
  }
}

import { Page, Locator } from "@playwright/test";
import { BasePage } from "./base.page";

export class ObservationSearchPage extends BasePage {
  constructor( page: Page ) {
    super( page );
  }

  async goto(): Promise<void> {
    await super.goto( "/observations" );
    await this.waitForPageReady();
  }

  getGridView(): Locator {
    return this.page.locator( "#subview-controls button", { hasText: /grid/i } );
  }

  getTableView(): Locator {
    return this.page.locator( "#subview-controls button", { hasText: /list/i } );
  }

  getMapView(): Locator {
    return this.page.locator( "#subview-controls button", { hasText: /map/i } );
  }

  getObservationCards(): Locator {
    return this.page.locator( ".observation-photo, .photo_cell, .ObservationsGridItem" );
  }

  getHeading(): Locator {
    return this.page.locator( "#filters h1" );
  }

  getStatsContainer(): Locator {
    return this.page.locator( "#stats-container" );
  }

  getObservationsStat(): Locator {
    return this.page.locator( "#obsstatcol" );
  }

  getStatColumns(): Locator {
    return this.page.locator( "#stats-container .statcol" );
  }

  getTaxonNameInput(): Locator {
    return this.page.locator( "input[name='taxon_name']" );
  }

  getPlaceNameInput(): Locator {
    return this.page.locator( "#place_name" );
  }

  getFilterToggle(): Locator {
    return this.page.locator( "#filter-container button.dropdown-toggle" );
  }

  getResultsContainer(): Locator {
    return this.page.locator( "#results" );
  }

  async switchToGrid(): Promise<void> {
    await this.getGridView().click();
  }

  async switchToTable(): Promise<void> {
    await this.getTableView().click();
  }

  async switchToMap(): Promise<void> {
    await this.getMapView().click();
  }
}

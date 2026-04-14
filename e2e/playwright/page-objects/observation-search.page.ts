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
    return this.page.locator( "[data-view='grid'], .grid-view, .icon-grid" ).first();
  }

  getTableView(): Locator {
    return this.page.locator( "[data-view='table'], .table-view, .icon-table" ).first();
  }

  getMapView(): Locator {
    return this.page.locator( "[data-view='map'], .map-view, .icon-map" ).first();
  }

  getObservationCards(): Locator {
    return this.page.locator( ".observation-photo, .photo_cell, .ObservationsGridItem" );
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

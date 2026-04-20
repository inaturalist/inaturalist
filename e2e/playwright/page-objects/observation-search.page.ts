import { Page, Locator } from "@playwright/test";
import { BasePage } from "./base.page";

export class ObservationSearchPage extends BasePage {
  constructor( page: Page ) {
    super( page );
  }

  async goto( params?: string ): Promise<void> {
    const path = params ? `/observations?${params}` : "/observations";
    await super.goto( path );
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

  // --- Boundary drawing controls ---

  getRectangleBoundaryButton(): Locator {
    return this.page.locator( "button.btn-rect" );
  }

  getCircleBoundaryButton(): Locator {
    return this.page.locator( "button.btn-circle" );
  }

  getResetBoundaryButton(): Locator {
    return this.page.locator( "button.btn-clear-shape" );
  }

  getCustomBoundaryLabel(): Locator {
    return this.page.locator( "span.geo.selected", { hasText: /custom boundary/i } );
  }

  getClearBoundaryIcon(): Locator {
    return this.page.locator(
      "span.geo.selected .glyphicon-remove-sign[ng-click=\"clearBoundary( )\"]"
    );
  }

  getObservationsStatValue(): Locator {
    return this.page.locator( "#obsstatcol .stat-value" );
  }

  async gotoWithRectBoundary(
    nelat: number,
    nelng: number,
    swlat: number,
    swlng: number
  ): Promise<void> {
    await this.goto(
      `subview=map&nelat=${nelat}&nelng=${nelng}&swlat=${swlat}&swlng=${swlng}`
    );
  }

  async gotoWithCircleBoundary(
    lat: number,
    lng: number,
    radius: number
  ): Promise<void> {
    await this.goto( `subview=map&lat=${lat}&lng=${lng}&radius=${radius}` );
  }
}

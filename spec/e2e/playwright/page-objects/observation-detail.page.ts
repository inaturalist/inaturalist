import { Page, Locator } from "@playwright/test";
import { BasePage } from "./base.page";

function buildDateDetails( dateStr: string ) {
  const d = new Date( dateStr );
  const year = d.getUTCFullYear();
  const month = d.getUTCMonth() + 1;
  const day = d.getUTCDate();
  const startOfYear = Date.UTC( year, 0, 1 );
  const week = Math.ceil( ( ( d.getTime() - startOfYear ) / 86400000 + 1 ) / 7 );
  return { date: `${year}-${String( month ).padStart( 2, "0" )}-${String( day ).padStart( 2, "0" )}`, week, month, hour: null, year, day };
}

function buildMockApiResponse( obsData: Record<string, unknown> ) {
  const observedOn = ( obsData["observed_on"] as string ) || "2024-01-01";
  const createdAt = ( obsData["created_at"] as string ) || new Date().toISOString();
  return {
    total_results: 1,
    page: 1,
    per_page: 1,
    results: [
      {
        id: obsData["id"],
        uuid: obsData["uuid"],
        quality_grade: obsData["quality_grade"] || "research",
        created_at: createdAt,
        updated_at: obsData["updated_at"] || new Date().toISOString(),
        observed_on: observedOn,
        observed_on_details: buildDateDetails( observedOn ),
        created_at_details: buildDateDetails( createdAt ),
        latitude: obsData["latitude"] || 1,
        longitude: obsData["longitude"] || 1,
        geojson: { type: "Point", coordinates: [obsData["longitude"] || 1, obsData["latitude"] || 1] },
        taxon: {
          id: obsData["taxon_id"] || 1,
          name: "Test Species",
          rank: "species",
          is_active: true
        },
        user: {
          id: obsData["user_id"],
          login: "e2e_test_user",
          name: "E2E Test User"
        },
        photos: [
          {
            id: 1,
            url: "https://static.inaturalist.org/photos/default/square.jpg",
            license_code: "cc-by-nc",
            attribution: "(c) E2E Test User",
            flags: []
          }
        ],
        sounds: [],
        obscured: false,
        mappable: true,
        spam: false,
        captive: false,
        out_of_range: false,
        comments_count: 0,
        identifications_count: 1,
        faves_count: 0,
        num_identification_agreements: 1,
        num_identification_disagreements: 0
      }
    ]
  };
}

export class ObservationDetailPage extends BasePage {
  constructor( page: Page ) {
    super( page );
  }

  async goto( id: number | string, obsData?: Record<string, unknown> ): Promise<void> {
    if ( obsData ) {
      const uuid = obsData["uuid"] as string;
      // Only intercept the observation fetch itself, not sub-resources like /taxon_summary or /quality_metrics
      await this.page.route(
        new RegExp( `/observations/${uuid}(\\?|$)` ),
        async route => {
          await route.fulfill( {
            status: 200,
            contentType: "application/json",
            body: JSON.stringify( buildMockApiResponse( obsData ) )
          } );
        }
      );
    }
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

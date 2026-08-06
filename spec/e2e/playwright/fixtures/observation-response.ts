import { Page } from "@playwright/test";

function buildDateDetails( dateStr: string ) {
  const d = new Date( dateStr );
  const year = d.getUTCFullYear();
  const month = d.getUTCMonth() + 1;
  const day = d.getUTCDate();
  const startOfYear = Date.UTC( year, 0, 1 );
  const week = Math.ceil( ( ( d.getTime() - startOfYear ) / 86400000 + 1 ) / 7 );
  return {
    date: `${year}-${String( month ).padStart( 2, "0" )}-${String( day ).padStart( 2, "0" )}`,
    week,
    month,
    hour: null,
    year,
    day
  };
}

export function buildObservationApiResponse( obsData: Record<string, unknown> ) {
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
          name: "E2E Test User",
          preferences: {}
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
        comments: ( obsData["comments"] as unknown[] ) || [],
        ofvs: ( obsData["ofvs"] as unknown[] ) || [],
        comments_count: ( ( obsData["comments"] as unknown[] ) || [] ).length,
        identifications_count: 1,
        faves_count: 0,
        num_identification_agreements: 1,
        num_identification_disagreements: 0
      }
    ]
  };
}

/**
 * Intercepts the inat-api /observations/:uuid fetch so a single observation
 * can be rendered without depending on the indexer or a populated ES cluster.
 * Only matches the observation fetch itself — sub-resources like
 * /taxon_summary or /quality_metrics pass through unmodified.
 */
export async function mockObservationFetch(
  page: Page,
  obsData: Record<string, unknown>
): Promise<void> {
  const uuid = obsData["uuid"] as string;
  await page.route(
    new RegExp( `/observations/${uuid}(\\?|$)` ),
    async route => {
      await route.fulfill( {
        status: 200,
        contentType: "application/json",
        body: JSON.stringify( buildObservationApiResponse( obsData ) )
      } );
    }
  );
}

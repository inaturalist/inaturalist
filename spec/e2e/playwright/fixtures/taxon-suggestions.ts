import { Page } from "@playwright/test";

function buildTaxon( name: string, id: number ) {
  return {
    id,
    uuid: `00000000-0000-0000-0000-0000000${id}`,
    name,
    rank: "species",
    rank_level: 10,
    is_active: true,
    iconic_taxon_id: 1,
    iconic_taxon_name: "Animalia",
    ancestor_ids: [1, id],
    matched_term: name,
    preferred_common_name: null,
    default_photo: null
  };
}

export function buildTaxaAutocompleteResponse( names: string[] ) {
  return {
    total_results: names.length,
    page: 1,
    per_page: names.length,
    results: names.map( ( name, i ) => buildTaxon( name, 90000 + i ) )
  };
}

export function buildVisionResponse( names: string[] ) {
  return {
    total_results: names.length,
    results: names.map( ( name, i ) => ( {
      vision_score: 0.9 - ( i / 100 ),
      frequency_score: 1,
      taxon: buildTaxon( name, 80000 + i )
    } ) )
  };
}

// The suggest-an-ID field searches on focus too, so the vision endpoint needs a route as well.
export async function mockTaxonSuggestions(
  page: Page,
  names: string[],
  visionNames: string[] = []
): Promise<void> {
  await page.route( /\/taxa\/autocomplete/, async route => {
    await route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( buildTaxaAutocompleteResponse( names ) )
    } );
  } );
  await page.route( /\/computervision\/score_observation/, async route => {
    await route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( buildVisionResponse( visionNames ) )
    } );
  } );
}

import { Page } from "@playwright/test";

/**
 * Minimal v2 taxon payload shaped like the node API's /taxa/:id response.
 * browse_photos injects results[0] into SERVER_PAYLOAD.taxon, so this only
 * needs enough for inaturalistjs's Taxon() and the photo browser shell.
 */
export function buildTaxonApiResponse( taxonData: Record<string, unknown> ) {
  const id = taxonData["id"];
  return {
    total_results: 1,
    page: 1,
    per_page: 1,
    results: [
      {
        id,
        uuid: taxonData["uuid"] ?? `taxon-${id}`,
        name: taxonData["name"] ?? "Test Species",
        rank: "species",
        rank_level: 10,
        iconic_taxon_name: "Animalia",
        is_active: true,
        preferred_common_name: "Test Species",
        ancestor_ids: [id],
        ancestors: [],
        children: [],
        default_photo: null,
        taxon_photos: [],
        extinct: false,
        observations_count: 0
      }
    ]
  };
}

/**
 * The taxa/photos bundle talks to the v2 API from the browser (controlled
 * terms via fetchTerms, then an observations photo search). None of that data
 * matters for a layout screenshot, so fulfill every v2 GET with an empty
 * result set to keep the rendered page deterministic.
 */
export async function mockTaxaPhotosApi( page: Page ): Promise<void> {
  await page.route( /\/v2\//, route =>
    route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( { total_results: 0, page: 1, per_page: 30, results: [] } )
    } )
  );
}

// --- Taxon detail page (/taxa/:id) ------------------------------------------

const STATIC = "https://static.inaturalist.org";

function samplePhoto( id: number ) {
  return {
    id,
    license_code: "cc-by-nc",
    attribution: "(c) E2E Observer, some rights reserved (CC BY-NC)",
    attribution_name: "E2E Observer",
    url: `${STATIC}/photos/${id}/square.jpg`,
    square_url: `${STATIC}/photos/${id}/square.jpg`,
    small_url: `${STATIC}/photos/${id}/small.jpg`,
    medium_url: `${STATIC}/photos/${id}/medium.jpg`,
    large_url: `${STATIC}/photos/${id}/large.jpg`,
    original_dimensions: { width: 2048, height: 1536 }
  };
}

function miniTaxon( over: Record<string, unknown> = {} ) {
  return {
    id: 48662,
    name: "Danaus plexippus",
    rank: "species",
    rank_level: 10,
    iconic_taxon_name: "Insecta",
    preferred_common_name: "Monarch",
    is_active: true,
    extinct: false,
    default_photo: samplePhoto( 1 ),
    ...over
  };
}

const ANCESTORS = [
  { id: 1, name: "Animalia", rank: "kingdom", rank_level: 70, iconic_taxon_name: "Animalia", preferred_common_name: "Animals", is_active: true },
  { id: 47120, name: "Arthropoda", rank: "phylum", rank_level: 60, iconic_taxon_name: "Arachnida", preferred_common_name: "Arthropods", is_active: true },
  { id: 47158, name: "Insecta", rank: "class", rank_level: 50, iconic_taxon_name: "Insecta", preferred_common_name: "Insects", is_active: true },
  { id: 47157, name: "Lepidoptera", rank: "order", rank_level: 40, iconic_taxon_name: "Insecta", preferred_common_name: "Butterflies and Moths", is_active: true },
  { id: 47932, name: "Nymphalidae", rank: "family", rank_level: 30, iconic_taxon_name: "Insecta", preferred_common_name: "Brush-footed Butterflies", is_active: true },
  { id: 48663, name: "Danaus", rank: "genus", rank_level: 20, iconic_taxon_name: "Insecta", preferred_common_name: "Milkweed Butterflies", is_active: true }
];

/**
 * Rich v2 taxon payload for the taxon detail page (/taxa/:id). Populates photos
 * (taxon_photos drives the hero), taxonomy (ancestors), and the Status tab
 * (conservation_statuses + listed_taxa). flag_counts is required — the app
 * reads it ~11× and would crash if it were undefined.
 */
export function buildTaxonShowResponse( taxonData: Record<string, unknown> ) {
  const id = taxonData["id"];
  const isGenus = taxonData["rank"] === "genus";
  const ancestors = isGenus ? ANCESTORS.slice( 0, 5 ) : ANCESTORS;
  return {
    total_results: 1,
    page: 1,
    per_page: 1,
    results: [
      {
        id,
        uuid: taxonData["uuid"] ?? `taxon-${id}`,
        name: isGenus ? "Danaus" : "Danaus plexippus",
        rank: isGenus ? "genus" : "species",
        rank_level: isGenus ? 20 : 10,
        iconic_taxon_name: "Insecta",
        is_active: true,
        extinct: false,
        preferred_common_name: isGenus ? "Milkweed Butterflies" : "Monarch",
        english_common_name: isGenus ? "Milkweed Butterflies" : "Monarch",
        wikipedia_url: "https://en.wikipedia.org/wiki/Monarch_butterfly",
        wikipedia_summary: "The monarch butterfly is a milkweed butterfly in the "
          + "family Nymphalidae, known for its long annual migration.",
        // Non-null makes the Highlights tab show its Discoveries + Wanted sections.
        complete_species_count: isGenus ? 8 : null,
        ancestor_ids: [...ancestors.map( a => a.id ), id],
        ancestors,
        children: [],
        default_photo: samplePhoto( 1 ),
        taxon_photos: [1, 2, 3, 4].map( pid => ( {
          taxon: miniTaxon( { id } ),
          photo: samplePhoto( pid )
        } ) ),
        flag_counts: { resolved: 0, unresolved: 0 },
        atlas_id: null,
        observations_count: 128473,
        photos_locked: false,
        vision: true,
        taxon_schemes_count: 2,
        taxon_changes_count: 0,
        establishment_means: {
          establishment_means: "native",
          establishment_means_label: "Native",
          place: { id: 1, display_name: "United States" }
        },
        conservation_status: {
          status: "VU", iucn: 30, status_name: "Vulnerable", authority: "IUCN Red List"
        },
        conservation_statuses: [
          {
            status: "VU", iucn: 30, status_name: "Vulnerable", authority: "IUCN Red List",
            geoprivacy: "obscured", url: null,
            description: "Population declining across its range.",
            place: { id: 0, admin_level: null, display_name: "Global" }
          }
        ],
        listed_taxa_count: 2,
        listed_taxa: [
          { id: 1, establishment_means: "native", place: { id: 1, admin_level: 0, display_name: "United States" }, list: { id: 1, title: "United States Check List" } },
          { id: 2, establishment_means: "introduced", place: { id: 2, admin_level: 0, display_name: "New Zealand" }, list: { id: 2, title: "New Zealand Check List" } }
        ]
      }
    ]
  };
}

function taxonNames( taxonId: unknown ) {
  return [
    { id: 1, taxon_id: taxonId, name: "Danaus plexippus", lexicon: "Scientific Names", is_valid: true, position: 0, place_taxon_names: [] },
    { id: 2, taxon_id: taxonId, name: "Monarch", lexicon: "English", is_valid: true, position: 0, place_taxon_names: [] },
    { id: 3, taxon_id: taxonId, name: "Mariposa monarca", lexicon: "Spanish", is_valid: true, position: 1, place_taxon_names: [] }
  ];
}

const SIMILAR_RESULTS = [
  { taxon: miniTaxon( { id: 48664, name: "Danaus gilippus", preferred_common_name: "Queen" } ), count: 42 },
  { taxon: miniTaxon( { id: 48665, name: "Limenitis archippus", preferred_common_name: "Viceroy" } ), count: 17 }
];

// Recent-observations carousel: inatjs.observations.search → /v2/observations.
function sampleObs( id: number ) {
  return {
    id,
    uuid: `obs-${id}`,
    observed_on: "2024-01-01",
    photos: [{
      id, uuid: `photo-${id}`, license_code: "cc-by-nc",
      url: `${STATIC}/photos/${id}/square.jpg`,
      square_url: `${STATIC}/photos/${id}/square.jpg`,
      small_url: `${STATIC}/photos/${id}/small.jpg`,
      medium_url: `${STATIC}/photos/${id}/medium.jpg`
    }],
    taxon: miniTaxon( { id: 48662 } ),
    user: { id, login: `observer${id}`, name: `Observer ${id}` }
  };
}
const RECENT_OBS = [11, 12, 13, 14, 15, 16].map( sampleObs );

// Highlights tab: trending (species_counts), discoveries (recent_taxa), wanted.
const TRENDING = [101, 102, 103, 104, 105, 106].map( tid => ( {
  count: 200 - tid,
  taxon: miniTaxon( { id: tid, name: `Danaus trendicus ${tid}`, preferred_common_name: `Trending ${tid}` } )
} ) );
const DISCOVERIES = [201, 202, 203, 204].map( tid => ( {
  taxon: miniTaxon( { id: tid, name: `Danaus novus ${tid}`, preferred_common_name: `Discovery ${tid}` } ),
  identification: { id: tid, uuid: `id-${tid}`, created_at: "2024-01-02T10:00:00+00:00", observation: { id: tid * 10 } }
} ) );
const WANTED = [301, 302, 303, 304].map( tid =>
  miniTaxon( { id: tid, name: `Danaus optatus ${tid}`, preferred_common_name: `Wanted ${tid}` } ) );

// Seasonality chart (About tab): inatjs.observations.histogram.
const HISTOGRAM = {
  results: {
    month_of_year: { 1: 12, 2: 20, 3: 35, 4: 50, 5: 80, 6: 65, 7: 40, 8: 30, 9: 25, 10: 18, 11: 10, 12: 8 },
    month: {}
  }
};

// Identifications tab: inatjs.exemplar_identifications.search → /v2/exemplar_identifications.
function exemplar( eid: number ) {
  return {
    id: eid,
    uuid: `exemplar-${eid}`,
    nominated_by_user: { id: 2, login: "nominator", name: "Nominator" },
    nominated_at: "2024-01-03T10:00:00+00:00",
    votes: [
      { vote_flag: true, user: { id: 3, login: "voter_one", name: "Voter One" } },
      { vote_flag: true, user: { id: 4, login: "voter_two", name: "Voter Two" } }
    ],
    identification: {
      id: eid,
      uuid: `exemplar-id-${eid}`,
      body: "Textbook example — note the wing venation and coloration.",
      created_at: "2024-01-02T09:00:00+00:00",
      user: { id: 5, login: "expert_ider", name: "Expert Identifier" },
      observation: {
        id: eid * 100,
        discussion_count: 3,
        photos: [{
          id: eid, uuid: `exemplar-photo-${eid}`, license_code: "cc-by-nc",
          url: `${STATIC}/photos/${eid}/square.jpg`,
          square_url: `${STATIC}/photos/${eid}/square.jpg`,
          small_url: `${STATIC}/photos/${eid}/small.jpg`,
          medium_url: `${STATIC}/photos/${eid}/medium.jpg`
        }],
        annotations: [
          { id: eid, uuid: `annotation-${eid}`, controlled_attribute: { id: 1, label: "Life Stage" }, controlled_value: { id: 2, label: "Adult" } }
        ]
      }
    }
  };
}
const EXEMPLAR = {
  results: [exemplar( 1 ), exemplar( 2 )],
  total_results: 2,
  page: 1,
  per_page: 30,
  category_counts: { upvoted: 2, downvoted: 0, no_votes: 0, not_nominated: 0 },
  category_controlled_terms: []
};

/**
 * Endpoint-aware mock for the taxon detail page. The blanket empty-v2 stub used
 * elsewhere would wipe the taxa.fetch response (and thus the photos), so this
 * returns the rich taxon for /v2/taxa/:id (both the species and genus taxa),
 * plus real data for the recent-observations carousel and each tab's fetch, and
 * an empty result set for everything else. Registered generic-first so the
 * specific routes (added later) win under Playwright's last-registered-first
 * matching. Endpoint paths are disjoint, so their relative order is irrelevant.
 */
export async function mockTaxonShowApi(
  page: Page,
  opts: { speciesId: number; genusId: number }
): Promise<void> {
  const json = ( obj: unknown ) => ( {
    status: 200, contentType: "application/json", body: JSON.stringify( obj )
  } );
  const empty = { total_results: 0, page: 1, per_page: 30, results: [] };

  await page.route( /\/v[12]\//, route => route.fulfill( json( empty ) ) );

  // Rails-origin endpoints (Articles links, Taxonomy names).
  await page.route( /\/taxa\/\d+\/links\.json/, route => route.fulfill( json( [] ) ) );
  await page.route( /\/taxon_names\.json/, route => route.fulfill( json( taxonNames( opts.speciesId ) ) ) );

  // Taxon description (About tab, Rails-origin fetch). The real endpoint runs the
  // server-side describers, which raise in the test env and render a NameError
  // into the "Source" section. Return a clean summary + describer headers — the
  // client reads X-Describer-Name/URL for the Source label and link.
  await page.route( /\/taxa\/\d+\/description/, route =>
    route.fulfill( {
      status: 200,
      contentType: "text/html",
      headers: {
        "X-Describer-Name": "Wikipedia",
        "X-Describer-URL": "https://en.wikipedia.org/wiki/Monarch_butterfly"
      },
      body: "<p>The monarch butterfly is a milkweed butterfly in the family "
        + "Nymphalidae, known for its bright orange-and-black wings and its "
        + "multi-generational annual migration across North America.</p>"
    } )
  );

  // Recent-observations carousel (search only — not histogram/species_counts).
  await page.route( /\/v[12]\/observations(\?|$)/, route =>
    route.fulfill( json( { results: RECENT_OBS, total_results: RECENT_OBS.length, total_bounds: null } ) ) );
  await page.route( /\/v[12]\/observations\/histogram/, route => route.fulfill( json( HISTOGRAM ) ) );

  // Highlights tab.
  await page.route( /\/v[12]\/observations\/species_counts/, route =>
    route.fulfill( json( { results: TRENDING, total_results: TRENDING.length } ) ) );
  await page.route( /\/v[12]\/identifications\/recent_taxa/, route =>
    route.fulfill( json( { results: DISCOVERIES, total_results: DISCOVERIES.length } ) ) );
  await page.route( /\/v[12]\/taxa\/\d+\/wanted/, route =>
    route.fulfill( json( { results: WANTED, total_results: WANTED.length } ) ) );

  // Similar tab.
  await page.route( /\/v[12]\/identifications\/similar_species/, route =>
    route.fulfill( json( { results: SIMILAR_RESULTS } ) ) );

  // Identifications tab.
  await page.route( /\/v[12]\/exemplar_identifications/, route => route.fulfill( json( EXEMPLAR ) ) );

  // Main taxon fetch — rich taxon (highest precedence). Species and genus.
  await page.route( new RegExp( `/v[12]/taxa/${opts.speciesId}(\\?|$)` ), route =>
    route.fulfill( json( buildTaxonShowResponse( { id: opts.speciesId } ) ) ) );
  await page.route( new RegExp( `/v[12]/taxa/${opts.genusId}(\\?|$)` ), route =>
    route.fulfill( json( buildTaxonShowResponse( { id: opts.genusId, rank: "genus" } ) ) ) );
}

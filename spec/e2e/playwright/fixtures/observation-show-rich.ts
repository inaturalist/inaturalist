import { Page } from "@playwright/test";
import { mockObservationSubresources } from "./observation-response";

// Deterministic sample data for the observation-show visual test. Every value
// is fixed (no dates/randomness) so screenshots are stable.
//
// The "research" variant is one fully-loaded observation that renders the
// maximum number of simultaneously-visible components. The other variants each
// isolate a mutually-exclusive rendering state (quality grade, location
// privacy, media type, taxon presence) that can't coexist with the others.

export type ObservationVariant =
  | "research"
  | "needs_id"
  | "casual"
  | "obscured"
  | "private"
  | "sound_only"
  | "no_taxon";

const STATIC = "https://static.inaturalist.org";

const observer = {
  id: 1,
  login: "e2e_observer",
  name: "E2E Observer",
  icon_url: `${STATIC}/attachments/users/icons/1/thumb.png`,
  observations_count: 214,
  roles: [],
  preferences: { prefers_community_taxa: true }
};

const identifier = ( id: number, login: string ) => ( {
  id,
  login,
  name: login.replace( /_/g, " " ),
  icon_url: `${STATIC}/attachments/users/icons/${id}/thumb.png`
} );

function sampleTaxon( overrides: Record<string, unknown> = {} ) {
  return {
    id: 48662,
    uuid: "taxon-48662",
    name: "Danaus plexippus",
    rank: "species",
    rank_level: 10,
    iconic_taxon_name: "Insecta",
    is_active: true,
    preferred_common_name: "Monarch",
    english_common_name: "Monarch",
    ancestor_ids: [1, 47120, 372739, 47157, 48662],
    // ancestry (slash-delimited ancestor ids, excluding self) drives the
    // community-ID progress bar in community_identification.jsx; without it the
    // ancestry matching fails and no vote cells render.
    ancestry: "1/47120/372739/47157",
    ancestors: [],
    default_photo: {
      url: `${STATIC}/photos/1/square.jpg`,
      square_url: `${STATIC}/photos/1/square.jpg`,
      medium_url: `${STATIC}/photos/1/medium.jpg`,
      attribution: "(c) E2E Observer, some rights reserved (CC BY-NC)",
      license_code: "cc-by-nc"
    },
    ...overrides
  };
}

function identification( o: Record<string, unknown> ) {
  return {
    id: o.id,
    uuid: `ident-${o.id}`,
    body: o.body ?? null,
    category: o.category ?? "supporting",
    current: o.current ?? true,
    disagreement: o.disagreement ?? false,
    hidden: false,
    vision: o.vision ?? false,
    spam: false,
    flags: [],
    created_at: "2024-01-03T09:00:00+00:00",
    taxon: o.taxon ?? sampleTaxon(),
    previous_observation_taxon: o.previousObservationTaxon ?? null,
    user: o.user,
    taxon_change: null
  };
}

function buildFixedDetails( year: number, month: number, day: number ) {
  return {
    date: `${year}-${String( month ).padStart( 2, "0" )}-${String( day ).padStart( 2, "0" )}`,
    week: Math.ceil( day / 7 ),
    month,
    hour: null,
    year,
    day
  };
}

const photos = [1, 2, 3, 4, 5, 6].map( id => ( {
  id,
  uuid: `photo-${id}`,
  url: `${STATIC}/photos/${id}/square.jpg`,
  license_code: "cc-by-nc",
  flags: [],
  moderator_actions: [],
  hidden: false
} ) );

const sounds = [{
  id: 1,
  uuid: "sound-1",
  file_url: `${STATIC}/sounds/1.mp3`,
  file_content_type: "audio/mpeg",
  license_code: "cc-by-nc",
  play_local: true,
  url: `${STATIC}/sounds/1.mp3`,
  flags: [],
  moderator_actions: [],
  hidden: false
}];

function baseObservation( uuid: unknown ) {
  const taxon = sampleTaxon();
  return {
    id: 999001,
    uuid,
    quality_grade: "research",
    created_at: "2024-01-02T12:00:00+00:00",
    created_at_details: buildFixedDetails( 2024, 1, 2 ),
    updated_at: "2024-01-04T12:00:00+00:00",
    observed_on: "2024-01-01",
    observed_on_details: buildFixedDetails( 2024, 1, 1 ),
    time_observed_at: "2024-01-01T15:30:00+00:00",
    observed_time_zone: "America/Los_Angeles",
    time_zone: "America/Los_Angeles",
    description: "Observed nectaring on milkweed along the trail. Wings in "
      + "excellent condition. Several others nearby.",
    species_guess: "Monarch",
    latitude: 37.8651,
    longitude: -119.5383,
    geojson: { type: "Point", coordinates: [-119.5383, 37.8651] },
    place_guess: "Yosemite National Park, CA, USA",
    place_ids: [1, 2, 3],
    positional_accuracy: 25,
    public_positional_accuracy: 25,
    obscured: false,
    geoprivacy: null,
    taxon_geoprivacy: null,
    mappable: true,
    map_scale: 10,
    captive: false,
    license_code: "cc-by-nc",
    quality_metrics: [],
    reviewed_by: [],
    identifications_most_agree: true,
    comments_count: 2,
    identifications_count: 5,
    faves_count: 3,
    num_identification_agreements: 4,
    num_identification_disagreements: 1,
    taxon,
    // The community taxon only forms once an observation has ≥2 identifications
    // (satisfied above), so a real value renders the community-ID panel. Same
    // taxon as the display taxon, the common "everyone agrees" case.
    community_taxon: taxon,
    user: observer,
    preferences: { prefers_community_taxon: true },
    photos,
    sounds,
    // A realistic research-grade progression: two IDs for Monarch, a dissenting
    // ID for a different species (Queen, a Danaus congener), then the community
    // re-converges on Monarch — 4 of 5 agree, so it stays research grade and the
    // community-ID bar shows one vote against.
    identifications: [
      identification( {
        id: 1, category: "improving", current: true, user: identifier( 2, "improving_ider" ),
        body: "Beautiful — the wing venation is a clear match for Monarch."
      } ),
      identification( { id: 2, category: "supporting", current: true, user: identifier( 3, "supporting_ider" ) } ),
      identification( {
        id: 3, category: "maverick", current: true, user: identifier( 4, "queen_ider" ),
        body: "I think this might be a Queen (Danaus gilippus) instead.",
        taxon: sampleTaxon( {
          id: 48663, uuid: "taxon-48663", name: "Danaus gilippus",
          preferred_common_name: "Queen", english_common_name: "Queen",
          ancestor_ids: [1, 47120, 372739, 47157, 48663]
        } )
      } ),
      identification( {
        id: 4, category: "improving", current: true, vision: true, user: identifier( 5, "vision_ider" ),
        body: "Agreeing back to Monarch — the vein pattern rules out Queen."
      } ),
      identification( { id: 5, category: "supporting", current: true, user: identifier( 6, "confirming_ider" ) } )
    ],
    comments: [
      { id: 1, uuid: "comment-1", body: "Beautiful specimen — thanks for sharing!", created_at: "2024-01-03T10:00:00+00:00", user: identifier( 3, "supporting_ider" ) },
      { id: 2, uuid: "comment-2", body: "Saw one near here last week too.", created_at: "2024-01-03T11:30:00+00:00", user: identifier( 7, "commenter" ) }
    ],
    annotations: [
      {
        uuid: "annotation-1",
        controlled_attribute: { id: 1, label: "Life Stage", multivalued: false },
        controlled_value: { id: 2, label: "Adult", multivalued: false },
        user: identifier( 2, "improving_ider" ),
        vote_score: 1,
        votes: [{ vote_flag: true, user: identifier( 3, "supporting_ider" ) }]
      }
    ],
    ofvs: [
      { uuid: "ofv-1", value: "Nectaring", name: "Behavior", datatype: "text", observation_field: { uuid: "of-1", name: "Behavior", datatype: "text", allowed_values: null, description: "" }, user: observer },
      { uuid: "ofv-2", value: "AATTCCGG", name: "DNA Barcode ITS", datatype: "dna", observation_field: { uuid: "of-2", name: "DNA Barcode ITS", datatype: "dna", allowed_values: null, description: "" }, user: observer },
      { uuid: "ofv-3", value: "Asclepias syriaca", name: "Associated species", datatype: "taxon", observation_field: { uuid: "of-3", name: "Associated species", datatype: "taxon", allowed_values: null, description: "" }, taxon: sampleTaxon( { id: 55482, name: "Asclepias syriaca", rank: "species", preferred_common_name: "Common Milkweed", iconic_taxon_name: "Plantae" } ), user: observer }
    ],
    tags: ["migration", "pollinator"],
    faves: [
      { id: 1, user: identifier( 2, "improving_ider" ) },
      { id: 2, user: identifier( 3, "supporting_ider" ) },
      { id: 3, user: identifier( 7, "commenter" ) }
    ],
    project_observations: [
      // admins: [] required — when logged in, MapDetails reads project.admins.map (map_details.jsx:105).
      { uuid: "po-1", current_user_is_member: false, preferences: { allows_curator_coordinate_access: true }, project: { id: 100, title: "Monarchs of North America", icon: `${STATIC}/projects/100-icon.png`, slug: "monarchs-na", admins: [] } }
    ],
    non_traditional_projects: [],
    outlinks: [],
    flags: [],
    // Vote-scoped votes drive the "can the Community Taxon be improved?"
    // (needs_id) DQA row. The container groups these by vote_scope, and the
    // metric reads vote_flag (quality_metrics.jsx:236). One voter each side.
    votes: [
      { id: 1, vote_scope: "needs_id", vote_flag: true, user: identifier( 2, "improving_ider" ) },
      { id: 2, vote_scope: "needs_id", vote_flag: false, user: identifier( 3, "supporting_ider" ) }
    ],
    application: { name: "iNaturalist Web", url: "https://www.inaturalist.org", icon: null }
  };
}

function applyVariant( obs: Record<string, unknown>, variant: ObservationVariant ) {
  switch ( variant ) {
    case "needs_id":
      return { ...obs, quality_grade: "needs_id", identifications_most_agree: false, num_identification_agreements: 1 };
    case "casual":
      return { ...obs, quality_grade: "casual", captive: true };
    case "obscured":
      // Coarse public point + obscured flag → obscured-location UI, month/year-only date.
      return { ...obs, obscured: true, geoprivacy: "obscured", positional_accuracy: null, public_positional_accuracy: 25000 };
    case "private":
      // No public coordinates at all → "no location" map state.
      return { ...obs, obscured: true, geoprivacy: "private", geojson: null, latitude: null, longitude: null, mappable: false };
    case "sound_only":
      return { ...obs, photos: [] };
    case "no_taxon":
      return { ...obs, taxon: null, community_taxon: null, identifications_most_agree: false, species_guess: "Some orange butterfly" };
    case "research":
    default:
      return obs;
  }
}

export function buildObservationForVariant( uuid: unknown, variant: ObservationVariant = "research" ) {
  return {
    total_results: 1,
    page: 1,
    per_page: 1,
    results: [applyVariant( baseObservation( uuid ), variant )]
  };
}

// taxonSummary is fetched separately and merged into taxon.taxon_summary; it
// drives the conservation-status and establishment-means badges.
const TAXON_SUMMARY = {
  conservation_status: {
    status: "VU",
    iucn_status: "vulnerable",
    status_name: "Vulnerable",
    authority: "IUCN Red List",
    place: { display_name: "Global" },
    description: "Population declining across its range."
  },
  listed_taxon: {
    establishment_means: "native",
    establishment_means_label: "Native",
    establishment_means_description: "Native to this place",
    place: { display_name: "United States" }
  },
  wikipedia_summary: "The monarch butterfly is a milkweed butterfly in the family Nymphalidae."
};

// The Data Quality Assessment votes load from a separate
// /observations/:uuid/quality_metrics fetch (see ducks/quality_metrics.js),
// not the observation payload. Without it every metric shows zero votes. Give a
// couple of agree votes across the standard metrics so the DQA is populated.
const QUALITY_METRICS = ["wild", "evidence", "recent", "date", "location", "subject"]
  .flatMap( ( metric, mi ) => [
    { id: mi * 2 + 1, metric, agree: true, user: identifier( 2, "improving_ider" ) },
    { id: mi * 2 + 2, metric, agree: true, user: identifier( 3, "supporting_ider" ) }
  ] );

// Annotations render from the controlled terms fetched via
// controlled_terms/for_taxon (ducks/controlled_terms.js), NOT the observation
// payload — without them the section shows "No Relevant Annotations" even with
// an annotation present. Life Stage (id 1 / value Adult id 2) matches the
// observation's annotation; Sex is an unused term so an empty add-row renders.
const CONTROLLED_TERMS = [
  {
    id: 1, label: "Life Stage", multivalued: false,
    values: [
      { id: 2, label: "Adult" }, { id: 3, label: "Teneral" }, { id: 4, label: "Pupa" },
      { id: 5, label: "Nymph" }, { id: 6, label: "Larva" }, { id: 7, label: "Egg" }
    ]
  },
  {
    id: 9, label: "Sex", multivalued: false,
    values: [{ id: 10, label: "Female" }, { id: 11, label: "Male" }]
  }
];

// The "Top Identifiers" panel loads from identifications/identifiers
// (ducks/identifications.js), separate from the observation payload.
const IDENTIFIERS = [
  { count: 128, user: identifier( 2, "improving_ider" ) },
  { count: 74, user: identifier( 3, "supporting_ider" ) },
  { count: 39, user: identifier( 5, "vision_ider" ) }
];

// Photo image files load from static.inaturalist.org, which is unreachable and
// non-deterministic from the test container. Serve a fixed solid-colour square
// per photo id (same colour across every requested size) so the photo column
// renders identically each run and can be asserted on instead of masked.
const PHOTO_COLOURS = ["#c0392b", "#27ae60", "#2980b9", "#f39c12", "#8e44ad", "#16a085"];

async function stubPhotoImages( page: Page ): Promise<void> {
  await page.route( /static\.inaturalist\.org\/photos\/(\d+)\//, route => {
    const id = Number( route.request().url().match( /\/photos\/(\d+)\// )?.[1] ?? 0 );
    const fill = PHOTO_COLOURS[( id - 1 ) % PHOTO_COLOURS.length];
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300">`
      + `<rect width="300" height="300" fill="${fill}"/></svg>`;
    return route.fulfill( { status: 200, contentType: "image/svg+xml", body: svg } );
  } );
}

// A viewer distinct from the observer (id 1) and every identifier (ids 2–7),
// with the interaction privilege. loggedIn + interaction is what gates the
// Agree and Compare buttons on activity items (see activity_item.jsx).
const VIEWER = {
  id: 99,
  login: "e2e_viewer",
  name: "E2E Viewer",
  icon_url: `${STATIC}/attachments/users/icons/99/thumb.png`,
  roles: [],
  privileges: ["interaction"],
  curator_project_ids: [],
  sites_admined: [],
  blockedUserHashes: [],
  blockedByUserHashes: [],
  trusted_user_ids: [],
  testGroups: [],
  content_creation_restrictions: false,
  preferred_observation_license: "cc-by-nc"
};

// Taxon::LIFE is nil in the test DB, so the server renders `var LIFE_TAXON = {}`.
// Inject a valid one so the community-ID modal is safe if it ever mounts/opens.
const LIFE_TAXON = { id: 48460, default_name: { name: "Life" } };

// The obs-show HTML is server-rendered logged-out, inlining `var CURRENT_USER = {}`
// and `var LIFE_TAXON = {}`. We must NOT rewrite the document to change these:
// serving the main document via route.fulfill makes Chromium fail every
// same-origin asset request (net::ERR_FAILED — CSS and JS never load, React
// never boots). Instead inject via addInitScript, which runs before the page's
// scripts. A plain global would be clobbered by the inline `var`, so define
// accessor properties whose setter ignores the logged-out reassignment.
async function injectLoggedInGlobals( page: Page ): Promise<void> {
  await page.addInitScript( ( { currentUser, lifeTaxon } ) => {
    const pin = ( name: string, value: unknown ) => Object.defineProperty( window, name, {
      configurable: true,
      enumerable: true,
      get: () => value,
      set: () => {}
    } );
    pin( "CURRENT_USER", currentUser );
    pin( "LIFE_TAXON", lifeTaxon );
  }, { currentUser: VIEWER, lifeTaxon: LIFE_TAXON } );
}

/**
 * Registers every route the obs-show page needs, in dependency order. Playwright
 * matches routes last-registered-first, so the generic empty stub goes first,
 * then the specific taxon_summary, then the main observation fetch last (highest
 * precedence). Call once per test before navigating.
 */
export async function setupObservationShow(
  page: Page,
  opts: { uuid: string; variant?: ObservationVariant }
): Promise<void> {
  await mockObservationSubresources( page );
  await stubPhotoImages( page );
  await injectLoggedInGlobals( page );

  await page.route( /\/observations\/[^/]+\/taxon_summary/, route =>
    route.fulfill( { status: 200, contentType: "application/json", body: JSON.stringify( TAXON_SUMMARY ) } )
  );

  await page.route( /\/observations\/[^/]+\/quality_metrics/, route =>
    route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( { total_results: QUALITY_METRICS.length, page: 1, per_page: 30, results: QUALITY_METRICS } )
    } )
  );

  await page.route( /\/controlled_terms/, route =>
    route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( { total_results: CONTROLLED_TERMS.length, page: 1, per_page: 30, results: CONTROLLED_TERMS } )
    } )
  );

  await page.route( /\/identifications\/identifiers/, route =>
    route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( { total_results: IDENTIFIERS.length, page: 1, per_page: 30, results: IDENTIFIERS } )
    } )
  );

  await page.route( new RegExp( `/v\\d/observations/${opts.uuid}(\\?|$)` ), route =>
    route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( buildObservationForVariant( opts.uuid, opts.variant ) )
    } )
  );
}

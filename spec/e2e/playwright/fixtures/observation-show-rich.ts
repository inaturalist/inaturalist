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

const photos = [1, 2].map( id => ( {
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
    identifications_count: 4,
    faves_count: 3,
    num_identification_agreements: 3,
    num_identification_disagreements: 1,
    taxon,
    // Left null on purpose: a non-null community_taxon makes CommunityIDModal
    // build its taxonomy table, which dereferences the LIFE_TAXON global. That
    // global is `{}` here because Taxon::LIFE is nil in the test DB, so it would
    // crash the whole React app (reading default_name.name of undefined).
    community_taxon: null,
    user: observer,
    preferences: { prefers_community_taxon: true },
    photos,
    sounds,
    identifications: [
      identification( {
        id: 1, category: "improving", current: true, user: identifier( 2, "improving_ider" ),
        body: "Agree — the wing venation is a clear match."
      } ),
      identification( { id: 2, category: "supporting", current: true, user: identifier( 3, "supporting_ider" ) } ),
      identification( {
        id: 3, category: "leading", current: false, user: identifier( 4, "withdrawn_ider" ),
        body: "Withdrawing my earlier ID."
      } ),
      identification( {
        id: 4, category: "improving", current: true, disagreement: true,
        user: identifier( 5, "disagreeing_ider" ),
        body: "Disagree with the finer ID; can only confirm to genus.",
        previousObservationTaxon: sampleTaxon( {
          id: 47157, name: "Danaus", rank: "genus", rank_level: 20, preferred_common_name: "Milkweed Butterflies"
        } )
      } ),
      identification( { id: 5, category: "supporting", current: true, vision: true, user: identifier( 6, "vision_ider" ) } )
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
      { uuid: "po-1", current_user_is_member: false, preferences: { allows_curator_coordinate_access: true }, project: { id: 100, title: "Monarchs of North America", icon: `${STATIC}/projects/100-icon.png`, slug: "monarchs-na" } }
    ],
    non_traditional_projects: [],
    outlinks: [],
    flags: [],
    votes: [],
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

  await page.route( /\/observations\/[^/]+\/taxon_summary/, route =>
    route.fulfill( { status: 200, contentType: "application/json", body: JSON.stringify( TAXON_SUMMARY ) } )
  );

  await page.route( new RegExp( `/v\\d/observations/${opts.uuid}(\\?|$)` ), route =>
    route.fulfill( {
      status: 200,
      contentType: "application/json",
      body: JSON.stringify( buildObservationForVariant( opts.uuid, opts.variant ) )
    } )
  );
}

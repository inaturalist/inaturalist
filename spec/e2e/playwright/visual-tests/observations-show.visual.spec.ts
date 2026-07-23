import { test, Page } from "@playwright/test";
import { setupObservationShow, ObservationVariant } from "../fixtures/observation-show-rich";
import { appMake } from "../support/on-rails";
import { expectVisualSnapshots } from "./helpers/visual-snapshot.helper";

test.describe( "observations show visual snapshots", () => {
  let obsUuid: string;

  test.beforeAll( async () => {
    const user = await appMake( "create", "user", {} );
    const taxon = await appMake( "create", "taxon", {} );
    const obs = await appMake( "create", "observation", {
      user_id: user.id, taxon_id: taxon.id, latitude: 1, longitude: 1, observed_on_string: "2024-01-01"
    } );
    obsUuid = obs.uuid as string;
  } );

  // Media + map load from external hosts; mask for stability, assert on layout.
  const mask = ( page: Page ) => [
    page.locator( "#ObservationShow .Map" ),
    page.locator( "#ObservationShow .photos_column" )
  ];

  const shot = ( variant: ObservationVariant, prefix: string ) =>
    expectVisualSnapshots( prefix, () => `/observations/${obsUuid}`, {
      waitForSelector: "#ObservationShow",
      mask,
      setup: page => setupObservationShow( page, { uuid: obsUuid, variant } )
    } );

  // The fully-loaded research-grade observation.
  shot( "research", "obs-show" );

  // Mutually-exclusive rendering states.
  const VARIANTS: ObservationVariant[] = ["needs_id", "casual", "obscured", "private", "sound_only", "no_taxon"];
  for ( const variant of VARIANTS ) {
    shot( variant, `obs-show-${variant}` );
  }
} );

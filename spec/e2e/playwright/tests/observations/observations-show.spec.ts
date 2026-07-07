import { test, expect } from "@playwright/test";
import { ObservationDetailPage } from "../../page-objects/observation-detail.page";
import { mockObservationFetch } from "../../fixtures/observation-response";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

test.describe( "Observation detail page", () => {
  let detailPage: ObservationDetailPage;

  test.beforeEach( async ( { page } ) => {
    const user = await appMake( "create", "user", {} );
    const taxon = await appMake( "create", "taxon", {} );
    const obs = await appMake( "create", "observation", {
      user_id: user.id,
      taxon_id: taxon.id,
      latitude: 1,
      longitude: 1,
      observed_on_string: "yesterday"
    } );
    await mockObservationFetch( page, obs );
    detailPage = new ObservationDetailPage( page );
    await detailPage.goto( obs.id as number );
  } );

  test( "loads and displays core observation content", async () => {
    await expect( detailPage.getPhoto() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getTaxonName() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getObserver() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getMap() ).toBeVisible( { timeout: 15_000 } );
  } );
} );

test.describe( "Observation detail page — long-username activity item", () => {
  let obs: Record<string, unknown>;
  const LONG_LOGIN = "jean_sebastien_chartier_dumais_de_montreal_quebec";

  test.beforeAll( async () => {
    const user = await appMake( "create", "user", {} );
    const taxon = await appMake( "create", "taxon", {} );
    obs = await appMake( "create", "observation", {
      user_id: user.id,
      taxon_id: taxon.id,
      latitude: 1,
      longitude: 1,
      observed_on_string: "yesterday"
    } );
  } );

  expectNoHorizontalOverflow( () => `/observations/${obs.id}`, {
    waitForSelector: "#ObservationShow .ActivityItem .title_text",
    setup: async page => {
      await mockObservationFetch( page, {
        ...obs,
        comments: [
          {
            id: 999999,
            uuid: "00000000-0000-0000-0000-000000000999",
            created_at: "2024-06-01T12:00:00+00:00",
            body: "A comment from a user whose login has no break opportunities.",
            hidden: false,
            flags: [],
            moderator_actions: [],
            user: { id: 987654, login: LONG_LOGIN, name: LONG_LOGIN }
          }
        ]
      } );
    }
  } );
} );

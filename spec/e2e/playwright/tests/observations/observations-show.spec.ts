import { test, expect } from "@playwright/test";
import { ObservationDetailPage } from "../../page-objects/observation-detail.page";
import { mockObservationFetch } from "../../fixtures/observation-response";
import { app, appMake } from "../../support/on-rails";
import { login } from "../../helpers/auth.helper";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

test.describe( "Observation detail page", () => {
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

  test.beforeEach( async ( { page } ) => {
    await mockObservationFetch( page, obs );
  } );

  test( "loads and displays core observation content", async ( { page } ) => {
    const detailPage = new ObservationDetailPage( page );
    await detailPage.goto( obs.id as number );
    await expect( detailPage.getPhoto() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getTaxonName() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getObserver() ).toBeVisible( { timeout: 15_000 } );
    await expect( detailPage.getMap() ).toBeVisible( { timeout: 15_000 } );
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
          },
          {
            id: 999998,
            uuid: "00000000-0000-0000-0000-000000000998",
            created_at: "2024-06-01T12:01:00+00:00",
            body: "Loremipsumdolorsitametconsecteturadipiscingelitseddoeiusmodtemporincididuntutlaboreetdoloremagnaaliquaenimadminimveniam",
            hidden: false,
            flags: [],
            moderator_actions: [],
            user: { id: 987654, login: LONG_LOGIN, name: LONG_LOGIN }
          },
          {
            // A bare <pre> block with a long non-wrapping line (as seen on the
            // real Gerald observation). Below the tablet breakpoint the activity
            // column is a cross-axis item of a column-flex, so this sets the
            // column's min-content and overflows the viewport unless capped.
            id: 999997,
            uuid: "00000000-0000-0000-0000-000000000997",
            created_at: "2024-06-01T12:02:00+00:00",
            body: "<pre>$ curl -s \"https://api.inaturalist.org/v1/observations/5890862\" | python -m json.tool | grep comments_count</pre>",
            hidden: false,
            flags: [],
            moderator_actions: [],
            user: { id: 987654, login: LONG_LOGIN, name: LONG_LOGIN }
          }
        ],
        ofvs: [
          {
            id: 1,
            uuid: "00000000-0000-0000-0000-000000000001",
            value: "1231204954092834509283450923845092834059823049582304958203495802394850923845098234509283405982034958",
            observation_field: {
              id: 1,
              uuid: "00000000-0000-0000-0000-000000000010",
              name: "Shell Breadth (ShB) in mm",
              datatype: "numeric"
            }
          },
          {
            id: 2,
            uuid: "00000000-0000-0000-0000-000000000002",
            value: "More than 10,000",
            observation_field: {
              id: 2,
              uuid: "00000000-0000-0000-0000-000000000020",
              name: "How many flower buds are present? For species in which individual flowers are clustered in flower heads, spikes or catkins (inflorescences), simply estimate the number of flower heads and not the number of individual flowers. Skip question for oaks.",
              datatype: "text",
              allowed_values: "None|1|2-5|6-20|21-100|101-500|501-1,000|1,001-10,000|More than 10,000"
            }
          }
        ]
      } );
    }
  } );

  test.describe( "with RtlTestGroupToggle", () => {
    const CURATOR_PASSWORD = "TestPass123!";
    let curator: Record<string, unknown>;

    test.beforeAll( async () => {
      curator = await app( "make_curator", { password: CURATOR_PASSWORD } ) as Record<string, unknown>;
    } );

    expectNoHorizontalOverflow( () => `/observations/${obs.id}`, {
      waitForSelector: "#ObservationShow .TestGroupToggle",
      setup: async page => {
        await login( page, curator.email as string, CURATOR_PASSWORD );
        await mockObservationFetch( page, obs );
      }
    } );
  } );
} );

import { test, expect } from "@playwright/test";
import { ObservationDetailPage } from "../../page-objects/observation-detail.page";
import { mockObservationFetch } from "../../fixtures/observation-response";
import { mockTaxonSuggestions } from "../../fixtures/taxon-suggestions";
import { app, appMake } from "../../support/on-rails";
import { login } from "../../helpers/auth.helper";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

test.describe( "Observation detail page", () => {
  let obs: Record<string, unknown>;
  const LONG_LOGIN = "jean_sebastien_chartier_dumais_de_montreal_quebec";
  const VIEWER_PASSWORD = "TestPass123!";
  let viewer: Record<string, unknown>;

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
    // The responsive obs-detail page is gated behind the responsive-obs-detail
    // test group, so the overflow checks below must run as a group member.
    viewer = await appMake( "create", "user", { password: VIEWER_PASSWORD } );
    await app( "add_test_group", { user_id: viewer.id, test_groups: "responsive-obs-detail" } );
  } );

  test.beforeEach( async ( { page } ) => {
    await mockObservationFetch( page, obs );
  } );

  // Anonymous, so out of the test group: this is the legacy-path smoke test.
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
      await login( page, viewer.email as string, VIEWER_PASSWORD );
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
      await app( "add_test_group", { user_id: curator.id, test_groups: "responsive-obs-detail" } );
    } );

    expectNoHorizontalOverflow( () => `/observations/${obs.id}`, {
      waitForSelector: "#ObservationShow .TestGroupToggle",
      setup: async page => {
        await login( page, curator.email as string, CURATOR_PASSWORD );
        await mockObservationFetch( page, obs );
      }
    } );
  } );

  test.describe( "suggest an identification", () => {
    const MENU = "ul.taxon-autocomplete";
    const INPUT = "input[name='taxon_name']";
    const IDENTIFIER_PASSWORD = "TestPass123!";
    let identifier: Record<string, unknown>;

    test.beforeAll( async () => {
      identifier = await appMake( "create", "user", { password: IDENTIFIER_PASSWORD } );
      await app( "grant_privilege", { user_id: identifier.id, privilege: "interaction" } );
    } );

    test.beforeEach( async ( { page } ) => {
      await page.setViewportSize( { width: 390, height: 844 } );
      await mockTaxonSuggestions( page, ["Typed Species"], ["Suggested Species"] );
      await login( page, identifier.email as string, IDENTIFIER_PASSWORD );
      await mockObservationFetch( page, obs );
      await new ObservationDetailPage( page ).goto( obs.id as number );
      await page.locator( "#comment-id-tabs-tab-add_id" ).click();
    } );

    test( "keeps the typed results up when the keyboard closes", async ( { page } ) => {
      const result = page.locator( `${MENU} li.ac-result`, { hasText: "Typed Species" } );
      await page.locator( INPUT ).fill( "Typed" );
      await expect( result ).toBeVisible();
      // let the debounced search settle, so a late re-open cannot mask the blur
      await page.waitForTimeout( 1000 );
      await page.locator( INPUT ).blur();
      await page.waitForTimeout( 500 );
      await expect( result ).toBeVisible();
    } );

    test( "keeps the vision suggestions up when the keyboard closes", async ( { page } ) => {
      const result = page.locator( `${MENU} li.ac-result`, { hasText: "Suggested Species" } );
      await page.locator( INPUT ).click();
      await expect( result ).toBeVisible();
      // let the debounced search settle, so a late re-open cannot mask the blur
      await page.waitForTimeout( 1000 );
      await page.locator( INPUT ).blur();
      await page.waitForTimeout( 500 );
      await expect( result ).toBeVisible();
    } );

    test( "closes the suggestions once a result is chosen", async ( { page } ) => {
      const result = page.locator( `${MENU} li.ac-result`, { hasText: "Suggested Species" } );
      await page.locator( INPUT ).click();
      await expect( result ).toBeVisible();
      await result.click();
      await expect( page.locator( INPUT ) ).toHaveValue( /Suggested Species/ );
      await expect( result ).toBeHidden();
    } );

    test( "closes the vision suggestions on a tap outside the field", async ( { page } ) => {
      const result = page.locator( `${MENU} li.ac-result`, { hasText: "Suggested Species" } );
      await page.locator( INPUT ).click();
      await expect( result ).toBeVisible();
      // let the debounced search settle, so a late re-open cannot mask the close
      await page.waitForTimeout( 1000 );
      await page.locator( "#ObservationShow" ).click( { position: { x: 5, y: 5 } } );
      await expect( result ).toBeHidden();
    } );

    test( "stays closed when the field is re-selected, until the text changes", async ( { page } ) => {
      const suggestion = page.locator( `${MENU} li.ac-result`, { hasText: "Suggested Species" } );
      const typed = page.locator( `${MENU} li.ac-result`, { hasText: "Typed Species" } );
      await page.locator( INPUT ).click();
      await expect( suggestion ).toBeVisible();
      // let the debounced search settle, so a late re-open cannot mask the close
      await page.waitForTimeout( 1000 );
      await page.locator( "#ObservationShow" ).click( { position: { x: 5, y: 5 } } );
      await expect( suggestion ).toBeHidden();

      await page.locator( INPUT ).click();
      await page.waitForTimeout( 1000 );
      await expect( suggestion ).toBeHidden();

      await page.locator( INPUT ).pressSequentially( "Typed" );
      await expect( typed ).toBeVisible();
    } );
  } );
} );

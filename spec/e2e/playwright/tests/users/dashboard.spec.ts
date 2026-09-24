import { test, expect, Page } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";
import { VIEWPORTS } from "../../../shared/breakpoints";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  // Enable the responsive dashboard. "responsive-global" flips the template
  // variant (responsive dashboard + subnav drawer); "responsive-header"
  // collapses the nav into a hamburger on narrow viewports. Both are needed for
  // the page-level overflow check to exercise the shipping responsive layout.
  await app( "add_test_group", {
    user_id: user.id,
    test_groups: ["responsive-header", "responsive-global"]
  } );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

expectNoHorizontalOverflow( "/home" );

// Controlled HTML for the two tab-content endpoints so tab-switching, pagination,
// and content-injection are deterministic without a live iNaturalistAPI. The
// updates fragment carries a responsive .page_button so pagination can be driven;
// the comments fragment is bare <li>s so fetchContent's ul.timeline wrap shows.
const UPDATES_HTML = `<ul class="timeline"><li id="mock-update">mock update</li></ul>
  <nav class="dashboard-pagination">
    <a class="btn btn-sm btn-default page_button" data-page="2" href="#">Next</a>
  </nav>`;
const COMMENTS_HTML = "<li class=\"mock-comment\">mock comment</li>";

async function mockDashboardEndpoints( page: Page ): Promise<void> {
  await page.route( "**/users/dashboard_updates**", route => route.fulfill( {
    status: 200, contentType: "text/html", body: UPDATES_HTML
  } ) );
  await page.route( "**/comments**", route => route.fulfill( {
    status: 200, contentType: "text/html", body: COMMENTS_HTML
  } ) );
  // The subscribe modal's show.bs.modal handler fetches this; keep it from erroring.
  await page.route( "**/subscriptions/new**", route => route.fulfill( {
    status: 200, contentType: "text/html", body: "<form></form>"
  } ) );
}

test.describe( "dashboard tab interactions", () => {
  test.beforeEach( async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xl );
    await mockDashboardEndpoints( page );
  } );

  test( "loads the default updates tab on page load", async ( { page } ) => {
    const [request] = await Promise.all( [
      page.waitForRequest( "**/users/dashboard_updates**" ),
      page.goto( "/home" )
    ] );
    expect( request.url() ).not.toContain( "filter=" );

    await expect( page.locator( "a[data-tab='updates']" ) ).toHaveClass( /\bactive\b/ );
    await expect( page.locator( "#updates_target #mock-update" ) ).toBeVisible();
    await expect( page.locator( "#updates_target" ) ).toHaveAttribute( "aria-busy", "false" );
  } );

  const tabCases = [
    { tab: "yours", url: "**/users/dashboard_updates**", param: "filter=you", target: "#updates_by_you_target" },
    { tab: "following", url: "**/users/dashboard_updates**", param: "filter=following", target: "#following_target" },
    { tab: "comments", url: "**/comments**", param: "partial=true", target: "#comments_target" }
  ];

  tabCases.forEach( ( { tab, url, param, target } ) => {
    test( `clicking the ${tab} tab activates it, fetches the right URL, and updates history`, async ( { page } ) => {
      await page.goto( "/home" );
      await expect( page.locator( "#updates_target #mock-update" ) ).toBeVisible();

      const [request] = await Promise.all( [
        page.waitForRequest( url ),
        page.locator( `a[data-tab='${tab}']` ).click()
      ] );
      expect( request.url() ).toContain( param );

      await expect( page.locator( `a[data-tab='${tab}']` ) ).toHaveClass( /\bactive\b/ );
      await expect( page.locator( "a[data-tab='updates']" ) ).not.toHaveClass( /\bactive\b/ );
      await expect( page.locator( target ) ).toBeVisible();
      await expect( page ).toHaveURL( new RegExp( `tab=${tab}` ) );
    } );
  } );

  test( "toggles aria-busy on the target while loading", async ( { page } ) => {
    await page.goto( "/home" );
    await expect( page.locator( "#updates_target #mock-update" ) ).toBeVisible();

    // Hold the "yours" fetch open so the busy state is observable, then release it.
    let release: () => void = () => {};
    const gate = new Promise<void>( resolve => { release = resolve; } );
    await page.route( "**/users/dashboard_updates**", async route => {
      await gate;
      await route.fulfill( { status: 200, contentType: "text/html", body: UPDATES_HTML } );
    } );

    await page.locator( "a[data-tab='yours']" ).click();
    await expect( page.locator( "#updates_by_you_target" ) ).toHaveAttribute( "aria-busy", "true" );

    release();
    await expect( page.locator( "#updates_by_you_target" ) ).toHaveAttribute( "aria-busy", "false" );
  } );

  test( "wraps returned comment li's in a ul.timeline", async ( { page } ) => {
    await page.goto( "/home" );
    await page.locator( "a[data-tab='comments']" ).click();
    await expect( page.locator( "#comments_target ul.timeline li.mock-comment" ) ).toBeVisible();
  } );

  test( "restores the previous tab on browser back", async ( { page } ) => {
    await page.goto( "/home" );
    await expect( page.locator( "#updates_target #mock-update" ) ).toBeVisible();

    await page.locator( "a[data-tab='yours']" ).click();
    await expect( page ).toHaveURL( /tab=yours/ );

    const [request] = await Promise.all( [
      page.waitForRequest( "**/users/dashboard_updates**" ),
      page.goBack()
    ] );
    expect( request.url() ).not.toContain( "filter=" );
    await expect( page.locator( "a[data-tab='updates']" ) ).toHaveClass( /\bactive\b/ );
  } );

  test( "loads the next page via the responsive pagination button", async ( { page } ) => {
    await page.goto( "/home" );
    await expect( page.locator( "#updates_target #mock-update" ) ).toBeVisible();

    const [request] = await Promise.all( [
      page.waitForRequest( "**/users/dashboard_updates**" ),
      page.locator( "#updates_target .page_button:not(.disabled)" ).click()
    ] );
    expect( request.url() ).toContain( "page=2" );
  } );

  test( "toggles subscribe modal labels by type", async ( { page } ) => {
    await page.goto( "/home" );
    const modal = page.locator( "#subscribeModal" );

    await page.locator( "a[data-subscribe-type='place']" ).click();
    await expect( page.locator( "#subscribePlaceLabel" ) ).toBeVisible();
    await expect( page.locator( "#subscribeTaxonLabel" ) ).toBeHidden();

    // The trigger opens the modal, whose overlay would intercept the next click.
    await modal.locator( ".close[data-dismiss='modal']" ).click();
    await expect( modal ).toBeHidden();
    await expect( page.locator( ".modal-backdrop" ) ).toHaveCount( 0 );

    await page.locator( "a[data-subscribe-type='taxon']" ).click();
    await expect( page.locator( "#subscribeTaxonLabel" ) ).toBeVisible();
    await expect( page.locator( "#subscribePlaceLabel" ) ).toBeHidden();
  } );
} );

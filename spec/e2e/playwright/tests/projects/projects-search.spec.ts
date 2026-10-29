import { expect, test, Page } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { appMake, app } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";
const ICON = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";
const UNBROKEN = "Unbrokenprojecttitlewithoutanyspacesthatmustnotoverflowitsrowonsmallscreens";

let testEmail: string;

function resultHtml( i: number ): string {
  return `
    <div class="search-result">
      <a href="/projects/fixture-${i}"><img alt="" src="${ICON}"></a>
      <div class="search-result-body">
        <h4><a href="/projects/fixture-${i}">${UNBROKEN}${i}</a></h4>
        <div class="meta">${UNBROKEN.repeat( 3 )} and a description that wraps normally across lines</div>
      </div>
    </div>
  `;
}

// Search results come from the Node API, absent under test, so result rows are spliced into the empty page
async function injectResults( page: Page ): Promise<void> {
  await page.route( "**/projects/search?q=*", async route => {
    const response = await route.fetch( { url: new URL( "/projects/search", route.request( ).url( ) ).href } );
    const body = ( await response.text( ) ).replace(
      /(<div class=["']browse-main["']>\s*<div class=["']browse-content["']>)/,
      `$1<div class="search-results">${[0, 1, 2].map( resultHtml ).join( "" )}</div>`
    );
    await route.fulfill( { response, body } );
  } );
}

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  await app( "add_test_group", { user_id: user.id, test_groups: "responsive-global" } );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

test.describe( "with results", ( ) => {
  expectNoHorizontalOverflow( "/projects/search?q=moths", {
    setup: injectResults,
    waitForSelector: ".search-results .search-result"
  } );
} );

test.describe( "without a query", ( ) => {
  expectNoHorizontalOverflow( "/projects/search", {
    waitForSelector: "#projects-search .project-search"
  } );
} );

test.describe( "at a phone width", ( ) => {
  test.use( { viewport: { width: 375, height: 800 } } );

  test( "search input fills the tools row", async ( { page } ) => {
    await page.goto( "/projects/search" );
    const [tools, form] = await Promise.all(
      ["#projects-search .browse-tools", "#projects-search .project-search"].map( s => page.locator( s ).boundingBox( ) )
    );
    expect( form?.width ).toEqual( tools?.width );
  } );
} );

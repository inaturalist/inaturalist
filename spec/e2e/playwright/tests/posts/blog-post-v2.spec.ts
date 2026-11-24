import { test, expect } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";
import { VIEWPORTS } from "../../../shared/breakpoints";

const TEST_PASSWORD = "TestPass123!";
const LONG_TITLE ="Pink riverweeds spotted on a morning run along a fast-moving river";

const RICH_BODY = [
  "<p>Riverweeds cling to rocks in rapids and waterfalls.</p>",
  "<p><img src=\"/favicon.ico\" width=\"1600\" height=\"900\" alt=\"A riverweed\"></p>",
  "<iframe width=\"560\" height=\"315\" src=\"https://www.youtube.com/embed/abc123\" title=\"A video\"></iframe>",
  "<blockquote><p>iNat is a fantastic tool to learn, to share, to teach.</p><p>Pablo</p></blockquote>"
].join( "" );

const LONG_URL = `https://example.org/form?id=${"S8tyj_P-KE6y24h2AnsLmegRZVdS03FPsCWrmqKgwmhU".repeat( 6 )}`;
const LONG_URL_BODY = `<p>Complete the form: <a href="${LONG_URL}">${LONG_URL}</a></p>`;

const WIDE_CELL = "Legacy-content-that-cannot-wrap-inside-the-column";
const LEGACY_BODY = `<table class="table table-striped table-condensed"><tr>${
  Array( 6 ).fill( `<td>${WIDE_CELL}</td>` ).join( "" )
}</tr></table>`;

let richPostPath: string;
let legacyPostPath: string;
let longUrlPostPath: string;

async function createBlogPost( attrs: Record<string, unknown> ): Promise<string> {
  const post = await app( "create_post", { parent_type: "Site", ...attrs } ) as Record<string, unknown>;
  return `/blog/${post.id}`;
}

test.beforeAll( async () => {
  await app( "enable_feature_flag", { key: "blog_v2" } );
  const user = await appMake( "create", "user", {} );
  const site = await appMake( "create", "site", {} );
  const base = { user_id: user.id, parent_id: site.id, title: LONG_TITLE };
  richPostPath = await createBlogPost( {
    ...base,
    body: RICH_BODY,
    tag_list: "riverweeds, rivers",
    cover: true,
    comment_count: 2
  } );
  legacyPostPath = await createBlogPost( { ...base, body: LEGACY_BODY } );
  longUrlPostPath = await createBlogPost( { ...base, body: LONG_URL_BODY } );
  await createBlogPost( base );
} );

test.describe( "blog post with a cover, images and an embed", () => {
  expectNoHorizontalOverflow( () => richPostPath, { waitForSelector: ".blog-post" } );
} );

test.describe( "legacy blog post with a wide table", () => {
  expectNoHorizontalOverflow( () => legacyPostPath, { waitForSelector: ".blog-post" } );

  test( "scrolls the table inside the post body region on phones", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xs );
    await page.goto( legacyPostPath );

    const region = page.getByRole( "region", { name: "Post content, scrolls sideways", exact: true } );
    const { scrollWidth, clientWidth } = await region.evaluate( el => ( {
      scrollWidth: el.scrollWidth,
      clientWidth: el.clientWidth
    } ) );
    expect( scrollWidth ).toBeGreaterThan( clientWidth );
  } );

  test( "keeps the stripes on Bootstrap 3 striped tables", async ( { page } ) => {
    await page.goto( legacyPostPath );
    await expect( page.locator( ".post-body tr" ).first() )
      .toHaveCSS( "background-color", "rgb(249, 249, 249)" );
  } );
} );

test.describe( "blog post with a long unbroken URL", () => {
  test( "wraps the URL instead of scrolling the post body on phones", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xs );
    await page.goto( longUrlPostPath );

    const region = page.getByRole( "region", { name: "Post content, scrolls sideways", exact: true } );
    const { scrollWidth, clientWidth } = await region.evaluate( el => ( {
      scrollWidth: el.scrollWidth,
      clientWidth: el.clientWidth
    } ) );
    expect( scrollWidth ).toBe( clientWidth );
  } );
} );

test.describe( "comments", () => {
  test( "open and close from the comments button", async ( { page } ) => {
    await page.goto( richPostPath );

    const toggle = page.locator( ".post-comments summary" );
    const readLabel = toggle.getByText( "Read all 2 comments" );
    const hideLabel = toggle.getByText( "Hide comments" );
    const list = page.locator( ".post-comments__list" );
    await expect( readLabel ).toBeVisible();
    await expect( hideLabel ).toBeHidden();
    await expect( list ).toBeHidden();

    await toggle.click();
    await expect( hideLabel ).toBeVisible();
    await expect( readLabel ).toBeHidden();
    await expect( list ).toBeVisible();

    await toggle.click();
    await expect( readLabel ).toBeVisible();
    await expect( list ).toBeHidden();
  } );

  test( "ask logged-out readers to sign in", async ( { page } ) => {
    await page.goto( richPostPath );
    await expect( page.getByRole( "link", { name: "Sign in to comment" } ) ).toBeVisible();
  } );

  test( "stay open on the new comment after posting one", async ( { page } ) => {
    const commenter = await appMake( "create", "user", { password: TEST_PASSWORD } );
    await app( "grant_privilege", { user_id: commenter.id } );
    await login( page, commenter.email as string, TEST_PASSWORD );
    await page.goto( richPostPath );

    await page.locator( ".post-comments summary" ).click();
    await page.locator( ".post-comments__details textarea" ).fill( "What a cool plant!" );
    await page.getByRole( "button", { name: "Post comment" } ).click();

    await expect( page.locator( ".post-comments__list" ) ).toBeVisible();
    await expect( page.locator( ".post-comments__list" ).getByText( "What a cool plant!" ) ).toBeInViewport();
  } );
} );

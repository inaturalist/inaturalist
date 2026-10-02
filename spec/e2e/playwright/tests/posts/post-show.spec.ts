import { test, expect } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";
import { VIEWPORTS } from "../../../shared/breakpoints";

const TEST_PASSWORD = "TestPass123!";
const LONG_TITLE = "A fairly long journal post title that has to wrap on narrow phone screens";

let testEmail: string;
let journalPostPath: string;
let blogPostPath: string;

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  await app( "add_test_group", {
    user_id: user.id,
    test_groups: ["responsive-header", "responsive-global"]
  } );
  const observation = await appMake( "create", "observation", { user_id: user.id } );
  const journalPost = await app( "create_post", {
    user_id: user.id,
    title: LONG_TITLE,
    observation_ids: [observation.id],
    comment_count: 1
  } ) as Record<string, unknown>;
  journalPostPath = `/journal/${user.login}/${journalPost.id}`;

  const site = await appMake( "create", "site", {} );
  const blogPost = await app( "create_post", {
    user_id: user.id,
    parent_type: "Site",
    parent_id: site.id,
    title: LONG_TITLE
  } ) as Record<string, unknown>;
  blogPostPath = `/blog/${blogPost.id}`;
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

test.describe( "journal post", () => {
  expectNoHorizontalOverflow( () => journalPostPath, { waitForSelector: ".post-layout" } );
} );

test.describe( "blog post", () => {
  expectNoHorizontalOverflow( () => blogPostPath, { waitForSelector: ".post-layout" } );
} );

test.describe( "post navigation", () => {
  test( "sits under the title and leaves the body full width on small screens", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xs );
    await page.goto( journalPostPath );

    const inlineNav = page.locator( ".post-nav-inline" );
    await expect( inlineNav ).toBeVisible();
    await expect( page.locator( ".post-nav-side" ) ).toBeHidden();
    await expect( inlineNav.getByRole( "link" ) ).toHaveText( ["Observations", "1 comment"] );

    const pageBox = await page.locator( ".post-layout" ).boundingBox();
    const contentBox = await page.locator( ".post-content" ).boundingBox();
    expect( contentBox?.width ).toBe( pageBox?.width );
  } );

  test( "stays in the sidebar on large screens", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xl );
    await page.goto( journalPostPath );

    const sideNav = page.locator( ".post-nav-side" );
    await expect( sideNav ).toBeVisible();
    await expect( page.locator( ".post-nav-inline" ) ).toBeHidden();
    await expect( sideNav.getByRole( "link" ) ).toHaveText( ["Observations", "1 comment"] );
  } );

  test( "is omitted and the body spans the full width when there is nothing to link to", async ( { page } ) => {
    await page.setViewportSize( VIEWPORTS.xl );
    await page.goto( blogPostPath );

    await expect( page.locator( ".post-nav" ) ).toHaveCount( 0 );
    const pageBox = await page.locator( ".post-layout" ).boundingBox();
    const contentBox = await page.locator( ".post-content" ).boundingBox();
    expect( contentBox?.width ).toBe( pageBox?.width );
  } );
} );

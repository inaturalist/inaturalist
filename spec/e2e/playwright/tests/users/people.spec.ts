import { test, expect } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  // "responsive-global" flips the +responsive template variant; "responsive-header"
  // collapses the nav on narrow viewports. Both are needed to exercise the shipping
  // responsive layout for the page-level overflow check.
  await app( "add_test_group", {
    user_id: user.id,
    test_groups: ["responsive-header", "responsive-global"]
  } );
  // A curator makes the /people curators grid actually render.
  await app( "make_curator" );
} );

test.beforeEach( async ( { page } ) => {
  // Both pages need a logged-in user: set_testing_responsive reads current_user,
  // and /people/leaderboard requires login outright.
  await login( page, testEmail, TEST_PASSWORD );
} );

// The helper's test titles are keyed only on the breakpoint, so wrap each call
// in a distinctly-named describe to keep the two routes' titles unique.
test.describe( "/people", () => {
  expectNoHorizontalOverflow( "/people" );
} );
test.describe( "/people/leaderboard", () => {
  expectNoHorizontalOverflow( "/people/leaderboard" );
} );

test.describe( "leaderboard responsive layout", () => {
  test( "stacks the three leaderboard columns into one at 375px", async ( { page } ) => {
    await page.setViewportSize( { width: 375, height: 900 } );
    await page.goto( "/people/leaderboard" );
    const columns = page.locator( ".LeaderboardGrid > .LeaderboardColumn" );
    await columns.first().waitFor();
    expect( await columns.count() ).toBe( 3 );

    const xs = await columns.evaluateAll(
      els => els.map( el => Math.round( el.getBoundingClientRect().x ) )
    );
    expect( new Set( xs ).size ).toBe( 1 );
  } );
} );

import { expect, test } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  await app( "add_test_group", { user_id: user.id, test_groups: "responsive-global" } );
  const suffix = Math.random( ).toString( 36 ).slice( 2 );
  await app( "create_projects", {
    titles: [
      `Unbrokenprojecttitlewithoutanyspacesthatmustnotoverflowitscard${suffix}`,
      `Browse responsive ${suffix} one`,
      `Browse responsive ${suffix} two`
    ]
  } );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

expectNoHorizontalOverflow( "/projects/browse", {
  waitForSelector: ".ProjectCardGrid .thumbnail"
} );

test( "renders without Blueprint", async ( { page } ) => {
  await page.goto( "/projects/browse" );
  await expect( page.locator( "link[href*='blueprint']" ) ).toHaveCount( 0 );
  await expect( page.locator( ".ProjectCardGrid .thumbnail" ).first( ) ).toBeVisible( );
} );

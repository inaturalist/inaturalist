import { test } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  // Enable the responsive header (collapses the nav into a hamburger on narrow
  // viewports) so the page-level overflow check exercises the shipping header.
  await app( "add_test_group", { user_id: user.id, test_groups: "responsive-header" } );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

expectNoHorizontalOverflow( "/home" );

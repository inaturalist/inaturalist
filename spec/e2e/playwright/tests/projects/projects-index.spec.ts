import { test } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  testEmail = user.email as string;
  await app( "add_test_group", { user_id: user.id, test_groups: "responsive-global" } );
} );

test.beforeEach( async ( { page } ) => {
  await login( page, testEmail, TEST_PASSWORD );
} );

expectNoHorizontalOverflow( "/projects", { waitForSelector: "#hero-container" } );

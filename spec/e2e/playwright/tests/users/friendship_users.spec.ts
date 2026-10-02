import { test } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;
let testLogin: string;
let friendLogin: string;

test.beforeAll( async () => {
  const user = await appMake( "create", "user", { password: TEST_PASSWORD } );
  const friend = await appMake( "create", "user", {
    login: `averylongloginthatdoesnotwrap_${Math.random().toString( 36 ).slice( 2 )}`.slice( 0, 40 ),
    name: "Someone With An Exceptionally Long Display Name That Should Wrap Or Truncate"
  } );
  testEmail = user.email as string;
  testLogin = user.login as string;
  friendLogin = friend.login as string;
  await app( "follow", { user_id: user.id, friend_id: friend.id } );
  await app( "follow", { user_id: friend.id, friend_id: user.id } );
  await app( "add_test_group", {
    user_id: user.id,
    test_groups: ["responsive-header", "responsive-global"]
  } );
} );

["followers", "following"].forEach( action => {
  test.describe( `/people/:login/${action}`, () => {
    const path = () => `/people/${testLogin}/${action}`;

    expectNoHorizontalOverflow( path, {
      setup: page => login( page, testEmail, TEST_PASSWORD )
    } );
  } );
} );

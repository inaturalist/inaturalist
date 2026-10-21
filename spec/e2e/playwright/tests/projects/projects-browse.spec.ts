import { expect, test, Page } from "@playwright/test";
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

// Header and @font-face still depend on Blueprint CSS, so measure page-relative, in whole pixels
async function layoutBoxes( page: Page ) {
  await page.goto( "/projects/browse" );
  const [root, ...boxes] = await Promise.all(
    ["#projects-browse", ".browse-tools", ".project-search", ".browse-tools .btn-inat", ".ProjectCardGrid .thumbnail"]
      .map( selector => page.locator( selector ).first( ).boundingBox( ) )
  );
  return boxes.map( box => [box!.x, box!.y - root!.y, box!.width, box!.height].map( Math.round ) );
}

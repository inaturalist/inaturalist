import { test, Page } from "@playwright/test";
import { login } from "../../helpers/auth.helper";
import { app, appMake } from "../../support/on-rails";
import { expectNoHorizontalOverflow } from "../../helpers/overflow.helper";
import { carouselHtml } from "../../helpers/carousel.helper";

const TEST_PASSWORD = "TestPass123!";

let testEmail: string;

// Hero projects come from the Node API, absent under test, so the carousel markup is spliced in
async function injectCarousel( page: Page ): Promise<void> {
  await page.route( "**/projects", async route => {
    const response = await route.fetch( );
    const body = ( await response.text( ) ).replace(
      /(<div class=["']hero["']>)/,
      `$1${carouselHtml( 3 )}`
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

expectNoHorizontalOverflow( "/projects", {
  setup: injectCarousel,
  waitForSelector: "[data-carousel-root][data-state]"
} );

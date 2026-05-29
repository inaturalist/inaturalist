import { Page } from "@playwright/test";
import { envConfig } from "../../shared/env.config";

export async function login(
  page: Page,
  email?: string,
  password?: string
): Promise<void> {
  const user = email || envConfig.testUser.email;
  const pass = password || envConfig.testUser.password;

  if ( !user || !pass ) {
    throw new Error( "Test user credentials not configured. Set E2E_TEST_USER_EMAIL and E2E_TEST_USER_PASSWORD." );
  }

  await page.goto( "/login" );
  const form = page.locator( "form.log-in" );
  await form.locator( "input[type='email']" ).fill( user );
  await form.locator( "input[type='password']" ).fill( pass );
  await Promise.all( [
    page.waitForURL( url => !url.pathname.startsWith( "/login" )
      && !url.pathname.startsWith( "/session" ), { timeout: 15_000 } ),
    form.locator( "input[type='submit'][name='commit']" ).click()
  ] );
}

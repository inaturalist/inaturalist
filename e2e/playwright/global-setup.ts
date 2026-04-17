import { chromium, FullConfig } from "@playwright/test";
import { envConfig } from "../shared/env.config";

async function globalSetup( config: FullConfig ) {
  const { testUser } = envConfig;
  if ( !testUser.email || !testUser.password ) {
    console.log( "No test user credentials configured — skipping auth setup" );
    return;
  }

  const browser = await chromium.launch();
  const page = await browser.newPage( {
    baseURL: envConfig.baseUrl
  } );

  await page.goto( "/login" );
  const form = page.locator( "form.log-in" );
  await form.locator( "input[type='email']" ).fill( testUser.email );
  await form.locator( "input[type='password']" ).fill( testUser.password );
  await Promise.all( [
    page.waitForURL( url => !url.pathname.startsWith( "/login" )
      && !url.pathname.startsWith( "/session" ), { timeout: 15_000 } ),
    form.locator( "input[type='submit'][name='commit']" ).click()
  ] );

  await page.context().storageState( { path: ".auth/storage-state.json" } );
  await browser.close();
}

export default globalSetup;

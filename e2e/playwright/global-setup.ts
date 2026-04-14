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
  await page.locator( "input[type='email']" ).fill( testUser.email );
  await page.locator( "input[type='password']" ).fill( testUser.password );
  await page.locator( "button.btn-inat.btn-primary" ).click();
  await page.waitForURL( /\//, { timeout: 15_000 } );

  await page.context().storageState( { path: ".auth/storage-state.json" } );
  await browser.close();
}

export default globalSetup;

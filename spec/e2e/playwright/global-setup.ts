import { chromium, FullConfig, request } from "@playwright/test";
import { envConfig } from "../shared/env.config";

async function verifyTestEnvironment(): Promise<void> {
  const context = await request.newContext( { baseURL: envConfig.baseUrl } );
  let railsEnv: string;
  try {
    const response = await context.post( "/__e2e__/command", {
      data: { name: "eval", options: "Rails.env.to_s" }
    } );
    if ( !response.ok() ) {
      throw new Error(
        `The Rails server at ${envConfig.baseUrl} does not expose /__e2e__/command ` +
        `(HTTP ${response.status()}). The server must run in test mode:\n\n` +
        `  RAILS_ENV=test bundle exec rails server -p 3001\n`
      );
    }
    const results = await response.json() as unknown[];
    railsEnv = String( results[0] );
  } finally {
    await context.dispose();
  }
  if ( railsEnv !== "test" ) {
    throw new Error(
      `Rails server is running in "${railsEnv}" mode. ` +
      `E2E tests must target a test-mode server to avoid corrupting real data.\n\n` +
      `Restart with:  RAILS_ENV=test bundle exec rails server -p 3001\n`
    );
  }
}

async function seedTestUser( email: string, password: string ): Promise<void> {
  const context = await request.newContext( { baseURL: envConfig.baseUrl } );
  try {
    const response = await context.post( "/__e2e__/command", {
      data: {
        name: "factory_bot",
        options: [["create", "user", { email, password }]]
      }
    } );
    if ( !response.ok() ) {
      const body = await response.text();
      // Email-uniqueness collision from a prior run is fine; the existing user
      // can still log in with the same password.
      if ( !/has already been taken|is already/i.test( body ) ) {
        throw new Error( `Failed to seed test user (${response.status()}): ${body}` );
      }
    }
  } finally {
    await context.dispose();
  }
}

async function globalSetup( config: FullConfig ) {
  await verifyTestEnvironment();

  const { testUser } = envConfig;
  if ( !testUser.email || !testUser.password ) {
    console.log( "No test user credentials configured — skipping auth setup" );
    return;
  }

  await seedTestUser( testUser.email, testUser.password );

  const browser = await chromium.launch();
  const page = await browser.newPage( {
    baseURL: envConfig.baseUrl
  } );

  try {
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
  } catch ( err ) {
    console.warn( `Auth setup failed for ${testUser.email} — skipping cached auth state. Tests requiring login will fail.\n${err}` );
  } finally {
    await browser.close();
  }
}

export default globalSetup;

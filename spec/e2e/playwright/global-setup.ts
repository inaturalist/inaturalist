import { request } from "@playwright/test";
import { envConfig } from "../shared/env.config";

/**
 * Aborts the suite before any tests run if the Rails server isn't in test mode.
 */
async function globalSetup() {
  const context = await request.newContext( { baseURL: envConfig.baseUrl } );
  try {
    const response = await context.post( "/__e2e__/command", {
      data: { name: "env" }
    } );
    if ( !response.ok() ) {
      throw new Error(
        `The Rails server at ${envConfig.baseUrl} does not expose /__e2e__/command ` +
        `(HTTP ${response.status()}). The server must run in test mode:\n\n` +
        `  RAILS_ENV=test bundle exec rails server -p 3001\n`
      );
    }
    const results = await response.json() as unknown[];
    const railsEnv = String( results[0] );
    if ( railsEnv !== "test" ) {
      throw new Error(
        `Rails server is running in "${railsEnv}" mode. ` +
        `E2E tests must target a test-mode server to avoid corrupting real data.\n\n` +
        `Restart with:  RAILS_ENV=test bundle exec rails server -p 3001\n`
      );
    }
    await context.post( "/__e2e__/command", { data: { name: "truncate_tables" } } );
  } finally {
    await context.dispose();
  }
}

export default globalSetup;

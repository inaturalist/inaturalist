import { app } from "./support/on-rails";

/**
 * Runs once before any worker. Verifies the target server is in test mode (the
 * dashboard seed does destructive teardown, so never touch a non-test DB), then
 * seeds the dashboard fixtures a single time. Doing this here — rather than in a
 * per-file beforeAll — avoids multiple parallel workers running the seed's
 * fixed-identity teardown/rebuild concurrently and corrupting each other.
 */
async function globalSetup(): Promise<void> {
  const railsEnv = await app( "env" ) as string;
  if ( railsEnv !== "test" ) {
    throw new Error(
      `Refusing to seed: Rails server is in "${railsEnv}" mode, not test. ` +
      "Start it with RAILS_ENV=test bundle exec rails server -p 3001."
    );
  }
  await app( "seed_dashboard", {} );
}

export default globalSetup;

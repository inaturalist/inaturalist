import path from "path";
import { defineConfig, devices } from "@playwright/test";
import { envConfig } from "../shared/env.config";

export default defineConfig( {
  globalSetup: "./global-setup",
  webServer: {
    command: "bundle exec rake inaturalist:generate_translations_js \
      && bundle exec rake assets:precompile \
      && bundle exec rails server -e test -p 3001",
    url: "http://localhost:3001/ping",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    // Eager-load the app: the classic autoloader is not thread-safe, and the
    // live multi-threaded Puma races on lazy autoloads otherwise. See test.rb.
    env: { RAILS_ENV: "test", E2E_EAGER_LOAD: "true" },
    cwd: path.resolve( __dirname, "../../.." )
  },
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? "html" : "list",
  timeout: 30_000,
  expect: {
    timeout: 10_000,
    toHaveScreenshot: {
      // Freeze CSS animations/transitions and hide the text caret so captures
      // are deterministic. A small tolerance absorbs sub-pixel font rendering
      // noise without hiding real layout regressions.
      animations: "disabled",
      caret: "hide",
      maxDiffPixelRatio: 0.01
    }
  },
  use: {
    baseURL: envConfig.baseUrl,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    headless: envConfig.headless
  },
  outputDir: "./test-results",
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    }
  ]
} );

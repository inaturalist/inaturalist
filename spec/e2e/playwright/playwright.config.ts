import path from "path";
import { defineConfig, devices } from "@playwright/test";
import { envConfig } from "../shared/env.config";

export default defineConfig( {
  globalSetup: "./global-setup",
  webServer: {
    command: "bundle exec rake inaturalist:generate_translations_js && bundle exec rails server -e test -p 3001",
    url: "http://localhost:3001/ping",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: { RAILS_ENV: "test" },
    cwd: path.resolve( __dirname, "../../.." )
  },
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: process.env.CI ? "html" : "list",
  timeout: 30_000,
  expect: {
    timeout: 10_000
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

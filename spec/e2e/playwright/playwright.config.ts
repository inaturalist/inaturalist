import { defineConfig, devices } from "@playwright/test";
import { envConfig } from "../shared/env.config";

export default defineConfig( {
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
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

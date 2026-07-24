import { defineConfig, devices } from "@playwright/test";

// host.docker.internal resolves on Mac Docker Desktop natively; on Linux the
// docker command adds --add-host=host.docker.internal:host-gateway.
const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? "http://host.docker.internal:3001";

// on-rails.ts talks to /__e2e__/command via envConfig.baseUrl (E2E_BASE_URL),
// which defaults to localhost — inside the Playwright container that's the
// container itself, not the host. Align it with the page baseURL here.
process.env.E2E_BASE_URL = process.env.E2E_BASE_URL ?? baseURL;

export default defineConfig( {
  testDir: "./visual-tests",
  snapshotDir: "./visual-snapshots",
  // Seeds shared, fixed-identity fixtures (the dashboard) exactly once, before
  // any worker starts — so no worker's teardown/rebuild races another's, and
  // running tests only ever read the seeded data.
  globalSetup: "./visual-global-setup",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1,
  // A single Rails backend is the bottleneck; too many parallel workers
  // saturate it (slow responses) and starve Chromium (page crashes).
  workers: process.env.CI ? 2 : 4,
  reporter: process.env.CI ? "html" : "list",
  timeout: 60_000,
  expect: {
    timeout: 30_000,
    toHaveScreenshot: { maxDiffPixels: 50 }
  },
  use: {
    baseURL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    // Pin explicitly: leaving this to the Desktop Chrome device default has
    // produced screenshots wider than the requested viewport in this Docker
    // image (e.g. 1052px captured for a 992px viewport), which throws off
    // gutter/layout comparisons.
    deviceScaleFactor: 1
  },
  outputDir: "./visual-test-results",
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    }
  ]
} );

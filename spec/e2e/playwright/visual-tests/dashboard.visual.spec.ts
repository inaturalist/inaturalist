import { login } from "../helpers/auth.helper";
import { expectVisualSnapshots } from "./helpers/visual-snapshot.helper";

// The dashboard fixtures are seeded once in visual-global-setup.ts (see
// spec/e2e/app_commands/seed_dashboard.rb). These credentials must match the
// fixed owner identity that command creates.
const OWNER_EMAIL = "e2edashboardowner@example.com";
const OWNER_PASSWORD = "DashboardPass123!";

expectVisualSnapshots( "dashboard", "/home", {
  // The timeline loads asynchronously into #updates_target. Match only the outer
  // list (nested .timeline_observation lists would make the locator non-strict).
  waitForSelector: "#updates_target > .timeline",
  setup: page => login( page, OWNER_EMAIL, OWNER_PASSWORD ),
  mask: page => [
    page.locator( ".UserPhoto img" ),
    page.locator( ".timeline-badge img" ),
    // Relative timestamps ("2 minutes ago") drift between runs.
    page.locator( ".timeline .time" )
  ]
} );

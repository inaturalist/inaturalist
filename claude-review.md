### Code review for branch `web-1381-quick-fix-geoip-lookup-on-logged-out-welcome-page`

Reviewed 1 commit (bd29a311f) with changes to 4 files, compared against origin/main.

No issues found. Checked for bugs and CLAUDE.md compliance.

Notes (below the reporting threshold, no action required):

- `app/models/announcement.rb:468-476` now hides country-targeted variants when no IP is
  given, where the old code skipped the filter entirely. All current callers pass an IP
  (`announcements_controller.rb:40`, `users_controller.rb:547`, `welcome_controller.rb:11-13`),
  git history shows the old behavior was an implicit gap rather than a decision, and the
  new comment plus specs at `spec/models/announcement_spec.rb:816-829` document it as intended.
- `welcome_controller.rb:11-13` adds a geoip lookup to every logged-out homepage view.
  `INatAPIService.get_json` (`lib/inat_api_service.rb:211`) rescues StandardError and
  returns nil on failure, and the call site in `announcement.rb:433-436` is nil-safe, so an
  API outage degrades gracefully. Only a 200 with a non-JSON body would raise
  (`lib/inat_api_service.rb:230`), and that path is pre-existing for the dashboard.

# Survey v0.2 implementation report

Historical backend report. The subsequent October 25
[private point-count pilot](protocols/stationary-bird-point-count-v1.md) adds a
Rails workflow and has now applied these migrations to the backed-up local
development database. The scope and results below describe the October 15 work.

Date: October 15, 2026. Branch: `feature/survey-schema-v0.2` in `web`.
Implementation and validation were completed on October 15; the changes were
prepared for local commits on October 16. No pull request has been created. See [schema and lifecycle documentation](survey_schema.md) and the
[architectural decision](decisions/001-survey-backend-v02.md).

## Delivered

All 13 requested tables and concrete Rails models are implemented. The graph is
protocol → immutable version → targets/measurement definitions → events → adopted
target assessments, participants, effort, detections, observation links and typed
measurements. Persistent sites and hierarchical units support repeated visits.
Existing users, taxa, places, Observations and STI Trips are referenced directly.

The five additive migrations are:

1. `20261015000001_create_survey_protocols.rb`: protocols, versions, biological
   targets and measurement definitions; publication constraints/triggers.
2. `20261015000002_create_survey_sampling.rb`: sites, units, spatial indexes,
   geometry checks and same-site hierarchy integrity.
3. `20261015000003_create_survey_events.rb`: events, adopted targets,
   participants, effort, snapshots and lifecycle/Trip guards.
4. `20261015000004_create_survey_results.rb`: detections, Observation links,
   typed measurements, composite FKs and absence-context checks.
5. `20261015000005_enforce_survey_completion.rb`: completion graph checks,
   retained unit geometry, stable identifiers and finite numeric values.

SQL definitions are versioned migration assets in `db/survey_v02/`. The final
`db/structure.sql` retains all legacy DDL and adds survey objects and the five
migration IDs. Migrations deliberately refuse automatic destructive rollback.

Concrete model files under `app/models/`:

```text
survey_protocol.rb             survey_protocol_version.rb
survey_target.rb               survey_measurement_definition.rb
survey_site.rb                 survey_sampling_unit.rb
survey_event.rb                survey_event_target.rb
survey_event_participant.rb    survey_effort.rb
survey_detection.rb            survey_observation.rb
survey_measurement.rb
```

`SurveyRecord` provides conservative default serialization and geometry inspect
filtering. `Surveys::GeometryType` preserves PostGIS behavior while redacting
routine Rails SQL geometry binds. Five requested service classes under `lib/`
implement publication, atomic initialization, completion and the two unlinking
operations. `SurveyEvent#void!` supplies the controlled terminal void transition.

Only seven lines were added to existing Trip Ruby code: an optional nullifying
association and `structured_survey_observations` using explicit links. Its legacy
observation discovery, taxon/purpose associations, and presence_absence methods
were preserved. A narrowly scoped trigger on Post STI type changes prevents a
referenced Trip from turning into an ordinary Post. No columns/indexes were added
to existing Posts, Observations or Taxa tables.

## Integrity and indexes

Verified in PostgreSQL: 13 new tables, 13 primary keys, 32 foreign keys,
43 CHECK constraints and 57 indexes (including primary/unique/spatial indexes).
The [architecture document](survey_schema.md#database-integrity-and-concurrency)
lists the constraint/index families and every trigger's rationale. The SQL dump
contains their exact definitions and names.

Core same-event, same-site, same-version, snapshot, ancestry, publication,
completion and historical deletion rules are enforced in PostgreSQL, including
writes that bypass Rails. No Elasticsearch relationships or counts were added.
A history-query EXPLAIN on the empty test database chose a sequential scan and
sort, as expected for an empty table; this is not a production-scale benchmark.
The `(survey_sampling_unit_id, started_at)` index is present for monitoring history.

## Verification

Runtime: Ruby 3.3.7, Rails 6.1.7.9, PostgreSQL 17.11, PostGIS 3.6.4.
Commands below ran from `web` after `source ../env.sh`. Local connection credentials
match the existing `config/database.yml`; no production service was contacted.

Fresh database migration checks loaded the original committed legacy structure
into empty databases, then ran all five migrations. Both initial and final
formatted migration files applied successfully. Final command:

```bash
SCHEMA=/tmp/survey-final-generated.sql RAILS_ENV=test \
DATABASE_URL=postgis://inaturalist:inaturalist@127.0.0.1/inaturalist_survey_v02_migration_test \
bundle exec rake db:migrate
```

The final dump was also loaded into a separate empty database. Schema-only dumps
of the migrated and loaded databases matched after normalizing PostgreSQL's
redundant string-array casts in CHECK expressions:

```bash
PGPASSWORD=inaturalist psql -h 127.0.0.1 -U inaturalist \
  -d inaturalist_survey_v02_dump_test -X -v ON_ERROR_STOP=1 \
  -f db/structure.sql
```

The dedicated survey suite, including nine multi-connection races:

```bash
RAILS_ENV=test \
DATABASE_URL=postgis://inaturalist:inaturalist@127.0.0.1/inaturalist_survey_v02_test \
bundle exec rspec spec/surveys/*_spec.rb
```

Result: **45 examples, 0 failures**. Tests cover all model types, typed values,
target materialization, persistence, inactive taxa/name snapshots, repeated visits,
absence semantics and reverse edits, direct SQL rejection, terminal history,
transaction rollback, default serialization, SQL logging, explicit Observation
links and Trip behavior. Concurrent tests verify actual database blocking with
`pg_blocking_pids`, not just coincident thread scheduling. They cover publication
and completion against child edits, simultaneous publication/completion attempts,
both hierarchies and idempotent ingestion.

Ordinary survey examples use rollback-only transactions and do not depend on
Elasticsearch/Qdrant. Concurrent examples commit across connections and clean only
the 13 survey tables plus their test user in `inaturalist_survey_v02_test`. They
skip on other database names to prevent destructive cleanup outside that dedicated
test database. Run them separately from the legacy global spec helper, whose
DatabaseCleaner hooks assume transaction-based examples.

The following non-concurrency tests also passed against the database created
solely from `db/structure.sql`: **36 examples, 0 failures**.

```bash
RAILS_ENV=test \
DATABASE_URL=postgis://inaturalist:inaturalist@127.0.0.1/inaturalist_survey_v02_dump_test \
bundle exec rspec spec/surveys/protocol_spec.rb spec/surveys/sampling_spec.rb \
  spec/surveys/event_spec.rb spec/surveys/results_spec.rb \
  spec/surveys/completion_spec.rb spec/surveys/trip_integration_spec.rb
```

Unmodified upstream Trip regression specs:

```bash
RAILS_ENV=test \
DATABASE_URL=postgis://inaturalist:inaturalist@127.0.0.1/inaturalist_survey_v02_test \
bundle exec rspec spec/models/trip_spec.rb spec/models/trip_taxon_spec.rb \
  spec/models/trip_purpose_spec.rb
```

Result: **14 examples, 0 failures, 2 pre-existing pending examples** (the two
unimplemented Trip updating examples). The first attempt stopped in the upstream
suite hook because Qdrant was not running. Starting the existing configured
service with `docker compose up -d --no-deps qdrant` resolved it; no test was
removed or disabled. This suite rebuilt its normal test search/vector indexes;
no application search mappings, jobs or search behavior were changed.

Static checks: **33 files inspected, no RuboCop offenses; `git diff --check` passed.**

```bash
RUBOCOP_CACHE_ROOT=/private/tmp/survey-rubocop-cache bundle exec rubocop --no-server \
  app/models/survey*.rb lib/*survey*.rb lib/surveys/*.rb \
  db/migrate/20261015*.rb spec/surveys/*.rb --format simple
git diff --check
```

The initial rollback test exposed nested-transaction leakage in event creation;
using a savepoint fixed it. Completion retries now clear prior validation errors.
Both fixes are covered by regression tests. No known survey test failures remain.
The full unrelated application test suite was not run.

## Data preservation and scope

No populated development database was reset, dropped, truncated, reseeded or
migrated. No development survey fixtures were created. Development remains on its
existing schema until the additive migrations are applied there. Test work used
`inaturalist_test` during phased development and the three isolated test databases
named above. The initial test database's early event guard was synchronized with
the final SQL asset without dropping/reloading any table. Final migration/dump
verification used fresh schemas, not that intermediate database.

No taxonomy or Observations schema/model/callback changes were made. No UI,
controller, API, JavaScript, dependency, mobile or Elasticsearch changes were made.
No taxonomic records were renamed or retargeted outside rolled-back tests.
No source files in `api` or `mobile` were changed.

## Differences, limits and next milestone

The complete list is in [schema decisions](survey_schema.md#deliberate-differences-and-follow-up-decisions).
Small added columns are a detection ingestion UUID and event privacy/completion/
void provenance. Protocol identity freezes on creation; planned events require a
published version. Correction is void-and-replace. Absence requires positive
quantified effort, and qualitative absence counts are rejected. Configuration is
intentionally limited and rejects unknown keys.

Rails-only behavior comprises time-zone name recognition, snapshot-name autofill,
initialization convenience, safe default serialization and routine SQL-bind
redaction. Persisted scientific and cross-table integrity is database-enforced.
Privacy is not complete: authorization, location disclosure, export policy,
operator statement-log handling, and arbitrary free-text disclosure need explicit
work before exposing this backend. Referenced users/taxa/places restrict deletion;
account erasure/anonymization requires a separate policy.

Next milestone: an authorized backend operation layer and a real point-count
workflow, resolving account retention, privacy and protocol effort thresholds
before adding an HTTP or UI surface. No generalized protocol language or export
system is included.

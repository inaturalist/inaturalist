# Feature Flags — Local Testing Guide

*WEB-1074 · branch `web-1074-flipper-install` · see also [feature_flags_ab_options.md](feature_flags_ab_options.md)*

How to verify the Flipper install locally. Covers the automated specs, a browser
walkthrough, and a scripted equivalent for when you want it fast and repeatable.

To *present* the install to the team rather than verify it, see
[feature_flags_demo.md](feature_flags_demo.md).

**What is in scope for this branch.** Flags evaluate server-side for **logged-in users
only** — anonymous visitors get every flag off by design. `GET /feature_flags` serves the
resolved map to non-web clients; the Node `/v2/feature_flags` that proxies it is not built
yet (WEB-1167), and there is no exposure logging (WEB-1173). `flipper_smoke_test` and
`hello_world` gate nothing; they exist to prove the pipeline. `demo_banner` gates the two
demo elements described in the demo guide.

---

## 0. Setup

```sh
bundle install
bundle exec rake db:migrate
RAILS_ENV=test bundle exec rake db:test:prepare
```

Then **restart the Rails server**.

> **If you develop in the dev container:** run `bundle install` on the **host** too, in a
> host terminal. The container installs into its own gem path and the host server has a
> separate bundle. Skipping this does not degrade gracefully — `config/routes.rb`
> references `Flipper::UI` at load time, so a missing gem means the whole route set fails
> to load and *every* page 500s with unrelated-looking `undefined local variable or method
> 'stats_path'` errors. Look for `uninitialized constant Flipper` in
> `log/development.log`. WEB-1171 added `flipper-active_support_cache_store` to the bundle,
> so the host needs another `bundle install` after pulling it.

Confirm the tables exist:

```sh
bundle exec rails runner 'puts ActiveRecord::Base.connection.tables.grep( /flipper/ ).inspect'
# => ["flipper_features", "flipper_gates"]
```

---

## 1. Specs

```sh
bundle exec rspec \
  spec/lib/feature_flagging*_spec.rb \
  spec/initializers/flipper_spec.rb \
  spec/controllers/feature_flags_controller_spec.rb \
  spec/helpers/application_helper_spec.rb
# => 0 failures
```

What each file is for:

| File | Covers |
|---|---|
| `feature_flagging_spec.rb` | The wrapper: declared flags, fail-closed reads, actor resolution, the `:admins` group, percentage determinism/monotonicity, variant independence, and one example against the real ActiveRecord adapter |
| `feature_flagging_ui_spec.rb` | The mount: anonymous/non-admin/curator all 404, admin 200, and a real GET-scrape-token-POST CSRF round trip |
| `feature_flagging_payload_spec.rb` | One real page per layout renders the flag map, and fails if a fourth layout starts emitting it uncovered |
| `feature_flagging_admin_spec.rb` | The dashboard readout, plus non-admins not seeing it |
| `feature_flagging_fail_closed_adapter_spec.rb` | `FeatureFlagging::FailClosedAdapter`: reads that raise log and report every flag off; writes re-raise |
| `feature_flagging_adapter_stack_spec.rb` | `FeatureFlagging.build_adapter`: memcached layer only for a `MemCacheStore`, 10 s TTL, env-prefixed keys, toggles expire the cache, fail-closed around the cache too |
| `feature_flagging_telemetry_spec.rb` | `FeatureFlagging::Telemetry`: the `feature_flag_*` counters and their presence in the request payload |
| `feature_flagging_preload_spec.rb` | Preload in the Memoizer middleware: one read per request, 200 with flags off when storage raises, toggles visible on the next request through the cache |
| `spec/initializers/flipper_spec.rb` | The initializer wiring: `build_adapter` is the configured storage, memoize and preload on, Memoizer innermost inside Makara, telemetry subscribed |

Specs use flipper's in-memory adapter, swapped fresh per example in `spec/spec_helper.rb`.
You do not need to reset flag state between examples. Flipper's own rspec helper is turned
off in `config/environments/test.rb` so `Flipper.configuration` keeps reflecting the
initializer.

Middleware order (memoizer should be innermost, inside Makara's context) is pinned by
`spec/initializers/flipper_spec.rb`; to eyeball it:

```sh
bundle exec rails middleware | grep -E "Makara|Flipper|Warden|Session"
# ActionDispatch::Session::ActiveRecordStore
# Warden::Manager
# Makara::Middleware
# Flipper::Middleware::Memoizer      <- last
```

And the storage stack (`active_support_cache_store` appears only where `Rails.cache` is memcached):

```sh
bundle exec rails runner 'puts Flipper.adapter.adapter_stack'
# memoizable -> actor_limit -> fail_closed_adapter -> instrumented -> ...
```

---

## 2. You need an admin account

The flag UI is admin-only. `is_admin?` means the global `admin` role, not site-admin, so
curators cannot reach it.

```sh
bundle exec rails runner '
u = User.find_by_login( "flipper_admin" ) || User.new(
  login: "flipper_admin",
  email: "flipper_admin@example.com",
  password: "flipperpass123",
  password_confirmation: "flipperpass123"
)
if u.new_record?
  u.confirmed_at = Time.now
  u.save!
  u.roles << ( Role.find_by_name( "admin" ) || Role.create!( name: "admin" ) )
end
puts "id=#{u.id} admin=#{u.reload.is_admin?} flipper_id=#{u.flipper_id}"
'
```

Use `rails runner` rather than raw SQL — Devise here uses
`restful_authentication_sha1`, not bcrypt, so hand-writing the digest is easy to get wrong.

---

## 3. Browser walkthrough

Signed in as that admin:

**a. Dashboard readout.** Go to `/admin`. There is a "Feature flags" panel showing whether
`flipper_smoke_test` is enabled for you and which `hello_world` variant you have, plus a
"Feature Flags" item in the left nav.

**b. Auth.** Open `/admin/feature_flags` — it redirects to `/admin/feature_flags/features`
and renders, with a red banner naming the environment. Then check it in a private window
(signed out) and as a non-admin account: both get a **404**, not a login redirect. That is
deliberate — the mount bypasses controllers, so the route constraint is the auth, and a 404
avoids advertising the path.

**c. Enable for yourself.** On the `flipper_smoke_test` feature page, add your flipper id
(`User;<your id>`) under Actors. The form must submit successfully — a `403 Forbidden` here
would mean the CSRF integration broke (see Troubleshooting).

**d. Propagation with no restart.** Reload `/admin` — the readout flips to `true`
immediately. Locally there is no cache layer at all (the development file store is
per-process, so `FeatureFlagging.shared_cache` is nil). In production flags are cached in
memcached for `FeatureFlagging::CACHE_TTL` (10 s), but a toggle made through flipper deletes
the affected keys, so changes still land on the very next request on every server. The TTL
only bounds staleness for writes that bypass flipper (raw SQL) or a read that refilled the
cache from a lagging replica.

**e. Delivery to the browser.** View source on any page and find:

```js
var CONFIG = {
  content_freeze_enabled: false,
  feature_flags: {"flipper_smoke_test":true}
};
```

In the JS console, `CONFIG.feature_flags` is an object. Check one page per layout —
`/observations` (bootstrap), `/id_summaries_demo` (basic), and any 404 page such as
`/pages/help` (application). Also confirm a signed-out window shows `false` on the same
page: the payload is per-user.

**f. Percentage rollout.** Set "% of actors" to 10, then 50, then 100 and watch the readout.
Remove your actor gate first, or it will mask the percentage result.

**g. Variant assignment.** On the `exp_hello_world` feature page, click Enable (fully
enable). Reload `/admin`: the readout moves from "not enrolled" to `control` or
`treatment`, and stays the same value on every reload.

**h. Rollback.** Disable both features. The readout returns to `false` / "not enrolled" and
all gate rows disappear.

---

## 4. Scripted equivalent

Faster than clicking, and useful for re-verifying after a change. Adjust `B` if your server
is elsewhere — from inside the dev container it is `http://host.docker.internal:3000`.

```sh
B=http://localhost:3000
J=$(mktemp)            # cookie jar

# Log in. --data-urlencode matters: CSRF tokens are base64 and a raw "+" would
# decode to a space, giving a silent 422.
TOK=$(curl -s -c $J "$B/login" \
  | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 \
  | sed 's/.*value="//; s/"$//')
curl -s -b $J -c $J -o /dev/null -w "login -> %{http_code}\n" \
  --data-urlencode "authenticity_token=$TOK" \
  --data-urlencode "user[email]=flipper_admin@example.com" \
  --data-urlencode "user[password]=flipperpass123" \
  "$B/session"                                    # => 302

# Helper: scrape a flipper CSRF token from a page that has a form.
# The features LIST page has no form, so no token -- use a feature page or /features/new.
tok() { curl -s -b $J -c $J "$1" \
  | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 \
  | sed 's/.*value="//; s/"$//'; }

F=$B/admin/feature_flags/features/flipper_smoke_test

# Enable for one actor, then set a percentage gate
curl -s -b $J -c $J -o /dev/null -w "actors  -> %{http_code}\n" \
  --data-urlencode "authenticity_token=$(tok $F)" \
  --data-urlencode "operation=enable" --data-urlencode "value=User;<your id>" "$F/actors"
curl -s -b $J -c $J -o /dev/null -w "percent -> %{http_code}\n" \
  --data-urlencode "authenticity_token=$(tok $F)" \
  --data-urlencode "value=10" "$F/percentage_of_actors"

# CSRF must actually be enforced
curl -s -b $J -c $J -o /dev/null -w "no token -> %{http_code}\n" \
  --data-urlencode "value=99" "$F/percentage_of_actors"        # => 403

# Flag map, signed in vs anonymous
curl -s -b $J -c $J "$B/observations" | grep -o 'feature_flags: {[^}]*}'   # => true
curl -s              "$B/observations" | grep -o 'feature_flags: {[^}]*}'  # => false

# Roll back
curl -s -b $J -c $J -o /dev/null -w "disable -> %{http_code}\n" \
  --data-urlencode "authenticity_token=$(tok $F)" \
  --data-urlencode "action=Disable" "$F/boolean"
```

Gate endpoints are `POST .../features/<name>/{actors,groups,percentage_of_actors,boolean}`.
`actors` and `groups` take `operation=enable|disable` plus `value`; `boolean` takes
`action=Enable|Disable`; the percentage gates take `value`.

Note `GET /` **302s to `/home`** when signed in, so pass `-L` if you test the root.

---

## 5. Bucketing properties in the console

This is the check worth running if you touch `FeatureFlagging.variant` or upgrade the gem.
It runs against the real ActiveRecord adapter.

```sh
bundle exec rails runner '
flag = :flipper_smoke_test
Flipper.disable( flag )
klass = Struct.new( :flipper_id )
actors = ( 1..1000 ).map {| i | klass.new( "User;#{i}" ) }
run = lambda { actors.select {| a | FeatureFlagging.enabled?( flag, a ) }.map( &:flipper_id ) }

Flipper.enable_percentage_of_actors( flag, 10 ); a10 = run.call; b10 = run.call
Flipper.enable_percentage_of_actors( flag, 20 ); a20 = run.call
Flipper.enable_percentage_of_actors( flag, 50 ); a50 = run.call
puts "deterministic: #{a10 == b10}"                                 # true
puts "sizes:         #{[a10.size, a20.size, a50.size].inspect}"     # ~100 / ~200 / ~500
puts "monotonic:     #{( a10 - a20 ).empty? && ( a20 - a50 ).empty?}"  # true

Flipper.enable( :exp_hello_world )
puts "variant split: #{actors.map {| a | FeatureFlagging.variant( :hello_world, a ) }.tally.sort.inspect}"
Flipper.disable( flag ); Flipper.disable( :exp_hello_world )
'
```

**Monotonic** matters: raising a percentage must only *add* actors, never reshuffle who is
already in. **Determinism** matters because it means a variant can be re-derived for any
user id later, so analysis needs no assignment table.

`variant` uses MD5, not the CRC32 sketched in Appendix A of the options doc. CRC32 is
linear, so two experiment names produce outputs differing by a constant XOR; taken modulo a
small variant count that made two 2-variant experiments perfectly anti-correlated. The
regression spec is *"assigns variants independently of other experiments"*. Flipper's own
percentage gate uses the same CRC32 construction but is unaffected in practice — its
threshold test is modulo 100,000, and measured cross-flag overlap stays within ~10% of
independent.

---

## 6. Resetting state

```sh
# Turn everything off but keep the features registered (the intended resting state)
bundle exec rails runner 'FeatureFlagging::KNOWN_FLAGS.each_key {| f | Flipper.disable( f ) }'

# Make sure every declared flag is registered. Preload only covers rows in
# flipper_features; a declared flag nobody has registered costs one extra read per request.
bundle exec rails runner 'FeatureFlagging::KNOWN_FLAGS.each_key {| f | Flipper.add( f ) }'

# Inspect what is stored
bundle exec rails runner '
puts ActiveRecord::Base.connection.select_all( "SELECT feature_key, key, value FROM flipper_gates" ).to_a.inspect
puts ActiveRecord::Base.connection.select_values( "SELECT key FROM flipper_features" ).inspect
'
```

Disabling removes gate rows but leaves the feature registered, which is correct — the
feature list is the inventory of flags, not the on/off state. Feature *deletion* is
disabled in the UI on purpose (`feature_removal_enabled = false`): it drops gate history and
silently turns a flag off everywhere.

---

## 7. Troubleshooting

| Symptom | Cause |
|---|---|
| Every page 500s, `undefined local variable or method 'stats_path'` | The flipper gems are not installed in the environment the **server** runs in, so `routes.rb` cannot load and the whole route set is gone. `bundle install` where the server runs, then restart. Confirm with `uninitialized constant Flipper` in the log. |
| `/admin/feature_flags` 404s while you are logged in | Not a global admin. `is_admin?` is `has_role?(:admin)`; curators and site admins do not qualify. |
| Any flag UI form gives `403 Forbidden` | The gem does its own CSRF with `Rack::Protection`, not Rails' `protect_from_forgery`, and it swallows every error into a bare 403. Verified working with `activerecord-session_store`, so suspect the session first: check `session["csrf"]` is set. `spec/lib/feature_flagging_ui_spec.rb` is the canary. |
| Scraping a CSRF token returns empty | You scraped the features **list** page. Only pages with forms emit `csrf_input_tag` — use `/features/new` or a specific feature page. |
| curl login returns 422 | You used `-d` instead of `--data-urlencode` for the base64 token. |
| Flags read `false` for a user you enabled | Percentage and actor gates need an actor. Anonymous requests resolve to no actor, where only a fully-enabled boolean gate applies. Confirm you are actually signed in — the payload is per-user. |
| `FeatureFlagging::UnknownFlagError` | The flag is not in `KNOWN_FLAGS`. That is deliberate: declare it there (with a one-line description) so typos and retired flags fail loudly instead of evaluating `false` forever. |
| A flag never appears in `CONFIG.feature_flags` | Only `CLIENT_FLAGS` are sent to browsers. Server-only flags stay out of page source on purpose. |
| Flags all report `false` and the log says `treating as off` | Reads are fail-closed and the `flipper_gates` query failed — most likely the migration has not run in that environment. |
| Flags all report `false` and the log says `adapter get_all failed` | Same cause, caught one layer lower: the preload in `Flipper::Middleware::Memoizer` failed and `FeatureFlagging::FailClosedAdapter` turned it into "all flags off" instead of a 500. Expect one more `adapter get failed` line per flag checked on that request. |
| `feature_flag_db_reads` is 1 on every production request | The memcached layer is not active. `Rails.cache` is not a `MemCacheStore` in that environment, or memcached is unreachable and every read is a miss (look for Dalli errors). |
| `feature_flag_db_reads` or `feature_flag_cache_reads` above 1 per request | A `KNOWN_FLAGS` key with no `flipper_features` row; preload cannot cover it. Register it (see §6). |
| A toggle shows on one server but not another for a few seconds | The other server refilled its cache from a lagging replica. Bounded by the 10 s TTL. |

---

## 8. Telemetry

Every request record Logstasher writes (`log/<env>.logstash.log`, `subtype: "ActionController"`)
carries four fields from `FeatureFlagging::Telemetry`, merged in by
`ApplicationController#append_info_to_payload`:

| Field | Meaning |
|---|---|
| `feature_flag_checks` | `FeatureFlagging.enabled?` calls during the request |
| `feature_flag_db_reads` | flipper reads that reached Postgres |
| `feature_flag_cache_reads` | flipper reads that reached memcached (0 where there is no cache layer) |
| `feature_flag_runtime` | milliseconds spent waiting on flipper storage |

An ordinary HTML page today makes 3 checks over 2 flags. Before WEB-1171 that was 2 DB reads
per request (one per distinct flag); with preload it is 1 (the `get_all` LEFT JOIN), and with
memcached it is 1 cache read and 0 DB reads on a hit. Locally:

```sh
curl -s -o /dev/null http://localhost:3000/observations
tail -1 log/development.logstash.log | grep -o '"feature_flag_[a-z_]*":[0-9.]*'
# "feature_flag_checks":3  "feature_flag_db_reads":1  "feature_flag_cache_reads":0  "feature_flag_runtime":...
```

These are the numbers to watch in Kibana after a deploy, and the numbers that decide whether
the cache layer and preload are still earning their keep.

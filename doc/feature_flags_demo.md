# Feature Flags — Demo Walkthrough

*WEB-1074 · branch `web-1074-flipper-install` · see also
[feature_flags_ab_options.md](feature_flags_ab_options.md) and
[feature_flags_local_testing.md](feature_flags_local_testing.md)*

How to show the team what the Flipper install does. `feature_flags_local_testing.md` covers
*verifying* the install; this covers *presenting* it, and explains how each team gets at flag
values.

**The one idea to land:** flags are evaluated **once, on the server, per user**. Every client —
server-rendered pages, React, and mobile — reads the same resolved answer. Nobody re-implements
targeting, and no client ever sees the rules.

---

## 0. Before you present

You need a **global admin** account (`has_role?( :admin )`; curators and site admins get a 404 at
the admin UI). Creating one locally is in `feature_flags_local_testing.md` §2.

Both demo elements are driven by one flag, `demo_banner`. Enable it for **named actors only** —
yourself, and anyone watching who wants to see it on their own screen. Do not use a boolean or
percentage gate: those make it public. Disable it when you are done.

If you are demoing locally and the React banner does not appear, you have stale bundles:

```sh
npx webpack --config config/webpack.config.js --mode=development
bundle exec rake inaturalist:generate_translations_js   # or the banner reads "[missing …]"
```

Neither step is needed on staging — the Docker build runs both.

---

## 1. The five-minute script

| # | Do this | Point at |
|---|---|---|
| 1 | Open `/admin` | The **Feature flags** panel. `demo_banner` is not shown here; `flipper_smoke_test` reads `false`. Nothing is on. |
| 2 | Open an observation page, e.g. `/observations/<id>` | No banner. Scroll to the footer — no badge. This is the "before". |
| 3 | Open `/admin/feature_flags` → `demo_banner` | This is the whole management surface. Four ways to turn a flag on: everyone, specific people, a group, or a percentage. |
| 4 | Under **Actors**, add your own `User;<your id>` and save | It saved to Postgres. **No deploy, no restart, no cache wait.** |
| 5 | Reload the observation page | The blue banner is now at the top **and** the badge is in the footer. One toggle, two independent rendering paths. |
| 6 | View Source, search `feature_flags` | `var CONFIG = { …, feature_flags: {"flipper_smoke_test":false,"demo_banner":true} }`. The page carries the *answers*, not the rules — no percentages, no actor lists. |
| 7 | In another browser, logged out, load the same page | Nothing. The flag is on for one person, not for the site. |
| 8 | `curl` the endpoint (below) | The same map as JSON. This is what mobile will read. |
| 9 | Back in the admin UI: remove your actor gate, set **Percentage of actors** to 50, reload a few times | Your value never flickers. Assignment is a hash of the user id, so it is stable and re-derivable — not a coin flip per request. |
| 10 | Set the percentage to 0 and remove the gates | Gone from both places on the next request. Note the feature still *exists* in the list — the list is the flag inventory, not the on/off state. |

**Two things worth saying out loud during step 9:** raising a percentage never re-rolls the people
already in it (10% ⊂ 30% ⊂ 50%), so a gradual rollout does not shuffle users; and two different
experiments bucket users independently, unlike the even/odd `Announcement::TARGET_GROUPS` split we
have today, where the same users land in the same half of every test.

---

## 2. Who can change what

- **Toggling flags:** global admins, at `/admin/feature_flags`. No engineer needed, no deploy, no
  release window. Changes apply on the **next request**.
- **Creating or removing a flag:** an engineer, in a PR. A flag has to be declared in
  `FeatureFlagging::KNOWN_FLAGS` (`lib/feature_flagging.rb`) before the app will read it — reading an
  undeclared key raises, so a typo or a deleted flag fails loudly instead of quietly evaluating
  `false` forever.
- **Deciding what a flag gates:** whoever writes the `if`. That is one line in a view or a component.

Deleting a feature is disabled in the UI on purpose (`feature_removal_enabled = false`): deleting it
discards the gate history and silently turns it off everywhere. Set it to 0% instead.

Flag *changes* are not currently audited — there is no record of who flipped what, when. That is
WEB-1177, and worth raising if anyone asks about controls.

---

## 3. How each team reads a flag

One evaluation, three delivery paths:

```
                  Flipper gates (Postgres, managed at /admin/feature_flags)
                                     |
              FeatureFlagging.enabled? / flags_for / variant     <- the only evaluator
                                     |
        +----------------------------+----------------------------+
        |                            |                            |
  ERB/HAML conditional      inline CONFIG.feature_flags     GET /feature_flags
  (server-rendered)         -> React / plain JS             (Rails JSON)
        |                            |                            |
     BUILT                        BUILT                        BUILT
                                                                  |
                                                        GET /v2/feature_flags
                                                        (Node proxy)  WEB-1167
```

### Rails / server-rendered pages

```erb
<% if FeatureFlagging.enabled?( :some_flag, current_user ) %>
```

Demo example: `app/views/shared/_footer.html.haml`. Add the flag to `KNOWN_FLAGS` and that is all.

### Web front end (React, Angular, jQuery)

```js
import featureFlagEnabled from "../../shared/feature_flags";

if ( featureFlagEnabled( "some_flag" ) ) { … }
```

`app/webpack/shared/feature_flags.js` reads the resolved map out of the inline `CONFIG` payload —
**no extra request**, and no flash of the wrong state, because the value is already in the HTML.
Demo example: `app/webpack/shared/components/feature_flag_demo_banner.jsx`.

A flag must be listed in `FeatureFlagging::CLIENT_FLAGS`, not just `KNOWN_FLAGS`, to be readable
here. That list is deliberately narrower: it keeps the names of unannounced features out of page
source. Anything not on it — including a misspelling — reads as off.

### Mobile (React Native)

```sh
curl -s https://www.inaturalist.org/feature_flags | jq
```

```json
{
  "flags":       { "flipper_smoke_test": false, "demo_banner": true },
  "experiments": { "hello_world": "treatment" }
}
```

Authentication is optional. Anonymous callers get `200` with everything off rather than a `401`, so a
client can fetch flags before it knows whether it has a session. A user JWT in the `Authorization`
header resolves that user's flags — the same warden strategy the rest of the API uses, so no
special-casing.

`Cache-Control: private, max-age=60`. The payload is per-user and must never reach a shared or CDN
cache; the short max-age stops a foregrounding app re-fetching on every navigation while still
picking up a toggle within about a minute.

**Client behaviour to implement** (from the contract in `feature_flags_ab_options.md` §3): fetch on
app startup and on foreground, persist the last map, and fail closed — on error use the last known
values, and default any unknown flag to **off**. Assignment is deterministic server-side, so
repeated polls return the same answers.

**What is still to build for mobile:**

| Issue | Work |
|---|---|
| WEB-1167 | `GET /v2/feature_flags` in the Node API — a controller that proxies this Rails endpoint with `InaturalistAPI.iNatJSWrap`, exactly as `app_build_info_controller.js` proxies Rails `/build_info`, plus the three `openapi/` files v2's strict response validation requires. The Rails half is done. |
| WEB-1168 | `lib/endpoints/feature_flags.js` in inaturalistjs. |
| WEB-1169 | Hand this contract to the React Native team for review. |

Mobile can call the Rails endpoint directly today to prototype against a real response.

---

## 4. Two limits to be honest about

**Logged-out users only get fully-enabled flags.** Percentage rollouts and actor gates need a stable
identity, and we do not give logged-out traffic one yet (WEB-1170). Right now that means a rollout to
"20% of users" is 20% of *logged-in* users and 0% of everyone else. For mobile specifically, the
application-level token authenticates as a single shared anonymous user, which the wrapper
deliberately treats as "no actor" — otherwise the entire logged-out mobile population would land in
one bucket and a 50% gate would resolve to 0% or 100% of it. `iNatJSWrap` already forwards
`X-Installation-ID`, which is the natural per-install actor when WEB-1170 lands.

Related, and inherent to any tool: the logged-in and anonymous identities are different actors, so a
user can change bucket when they log in, and one person on web and phone occupies two anonymous
buckets. Fine for rollouts. For experiments, prefer targeting logged-in users only.

**A/B assignment works; measurement does not exist yet.** `FeatureFlagging.variant` assigns users to
variants deterministically, and because it is a pure hash of the experiment name and user id, an
analyst can re-derive any user's variant after the fact with no assignment table. But nothing writes
an exposure event, so there is no funnel to analyze in Grafana — that is WEB-1173. If someone hears
"A/B testing" and expects results, this is the gap.

---

## 5. Cleanup

The demo is meant to be deleted. When the first real flag ships, remove:

- `demo_banner` from `KNOWN_FLAGS` and `CLIENT_FLAGS` in `lib/feature_flagging.rb`
- the guarded block in `app/views/shared/_footer.html.haml`
- `app/webpack/shared/components/feature_flag_demo_banner.jsx` and its import and render in
  `app/webpack/observations/show/components/app.jsx`
- `feature_flag_demo_banner` and `feature_flag_demo_footer_badge` from `config/locales/en.yml`
- `spec/lib/feature_flagging_demo_spec.rb`
- the pilot readout block in `app/views/admin/index.html.erb`, and this file

Keep `app/webpack/shared/feature_flags.js` and everything in §3 — that is the actual plumbing.

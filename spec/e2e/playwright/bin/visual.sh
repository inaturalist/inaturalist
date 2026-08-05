#!/usr/bin/env bash
#
# Runs the visual regression suite end to end: build fresh assets, boot a
# throwaway test-mode Rails server, run Playwright, tear it all down.
#
# Assets and Rails run directly on this machine. Only Playwright is
# containerized, for deterministic browser and font rendering; it reaches Rails
# at host.docker.internal:3001. That indirection is why the server lifecycle
# cannot live in Playwright's `webServer` config — that would try to boot Rails
# inside the Playwright image, which has no Ruby. So this script owns it.
#
# Any arguments are forwarded to `playwright test`:
#
#   npm run test:visual -- visual-tests/dashboard.visual.spec.ts
#   npm run test:visual -- -g "renders at the md breakpoint"
#
# Env overrides:
#   VISUAL_PORT        port for the test server (default: 3001)
#   VISUAL_PUBLISH_UI  set to 1 to publish 9323 for `--ui` mode

set -euo pipefail

readonly PORT="${VISUAL_PORT:-3001}"
readonly PLAYWRIGHT_IMAGE="mcr.microsoft.com/playwright:v1.60.0-noble"
readonly SERVER_LOG="log/visual-server.log"
readonly BOOT_TIMEOUT=180

REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../../.." && pwd )"
readonly REPO_ROOT
cd "$REPO_ROOT"

die() { printf '\nerror: %s\n\n' "$1" >&2; exit 1; }
step() { printf '\n\033[1;36m==>\033[0m \033[1m%s\033[0m\n' "$1"; }

# The server log is otherwise unread, so surface its tail when the server is
# the thing that broke.
die_with_log() {
  printf '\n--- last 40 lines of %s ---\n' "$SERVER_LOG" >&2
  tail -n 40 "$SERVER_LOG" >&2 2>/dev/null || true
  printf -- '--- end of log ---\n' >&2
  die "$1"
}

command -v docker >/dev/null 2>&1 || die "docker not found; needed to run Playwright."
command -v bundle >/dev/null 2>&1 || die "bundle not found; needed to build assets and run Rails."

# --- preflight ---------------------------------------------------------------
# Refuse to share the port. Reusing a server we did not build assets for is
# exactly how a run silently passes against stale CSS.
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  die "Port $PORT is already in use.
       The visual suite needs to own a fresh test server so it can guarantee
       the assets match your working tree. Stop the existing server and re-run."
fi

# --- teardown ----------------------------------------------------------------
# Registered before the server starts so a failure mid-boot still cleans up.
# Removes public/assets (so a later manual `rails s -e test` goes back to live
# compilation instead of being shadowed by a stale manifest) but deliberately
# keeps tmp/cache/assets, which is what makes the next precompile incremental.
server_pid=""
teardown() {
  local status=$?
  set +e
  step "Tearing down"
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null
    wait "$server_pid" 2>/dev/null
    echo "  stopped Rails server"
  fi
  rm -rf public/assets
  echo "  removed public/assets (kept tmp/cache/assets)"
  (( status != 0 )) && echo "  server log retained at $SERVER_LOG"
  exit "$status"
}
trap teardown EXIT

# --- build assets ------------------------------------------------------------
step "Building assets (clobber + precompile)"
export RAILS_ENV=test
bundle exec rake inaturalist:generate_translations_js
bundle exec rake assets:clobber
bundle exec rake assets:precompile

# --- boot the server ---------------------------------------------------------
# E2E_EAGER_LOAD: the classic autoloader is not thread-safe and multi-threaded
# Puma races on lazy autoloads. See config/environments/test.rb.
# -b 0.0.0.0: the Playwright container reaches us via host.docker.internal, so
# binding to loopback only would be unreachable from it.
# Puma's output is redirected to a file rather than inherited: it keeps logging
# request lines for the whole run, which would otherwise scribble over
# Playwright's progress reporter in the terminal.
step "Starting test server on port $PORT"
mkdir -p tmp/pids log
E2E_EAGER_LOAD=true bundle exec rails server -e test -p "$PORT" -b 0.0.0.0 \
  > "$SERVER_LOG" 2>&1 &
server_pid=$!
echo "  logging to $SERVER_LOG"

printf '  waiting for /ping'
for (( i = 0; i < BOOT_TIMEOUT; i++ )); do
  if curl -sf -o /dev/null "http://localhost:$PORT/ping"; then
    printf ' ready\n'
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    printf '\n'
    die_with_log "Rails server exited during boot."
  fi
  if (( i == BOOT_TIMEOUT - 1 )); then
    printf '\n'
    die_with_log "Server did not answer /ping within ${BOOT_TIMEOUT}s."
  fi
  printf '.'
  sleep 1
done

# --- run the suite -----------------------------------------------------------
# Accumulated into one array rather than expanded inline: macOS ships bash 3.2,
# where `"${arr[@]}"` on an *empty* array trips `set -u` ("unbound variable").
# Bash only fixed that in 4.4, so keep this array non-empty at every expansion,
# and guard "$@" with the ${@+...} idiom for the no-arguments case.
step "Running visual tests"
docker_args=(
  run --rm
  --shm-size=1gb
  --platform=linux/amd64
  --add-host=host.docker.internal:host-gateway
  --volume "$REPO_ROOT:/work"
  --workdir /work
)
[[ "${VISUAL_PUBLISH_UI:-}" == "1" ]] && docker_args+=( --publish 9323:9323 )
docker_args+=(
  "$PLAYWRIGHT_IMAGE"
  npx playwright test --config=spec/e2e/playwright/playwright.visual.config.ts
  ${@+"$@"}
)

docker "${docker_args[@]}"

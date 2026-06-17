# Claude Code Sandbox (dev container)

A Cursor/VS Code dev container for running Claude Code against the iNaturalist
repo behind a network egress allowlist. It follows Anthropic's reference
devcontainer pattern: a single image plus an iptables allowlist — no proxy.

## How it works

```
Claude Code / gh / git / npm   (vscode user, passwordless sudo)
        │  all outbound traffic
        ▼
   iptables allowlist  (init-firewall.sh, applied at every container start)
        ├── loopback, established/related, DNS (53)                ACCEPT
        ├── GitHub published ranges (api.github.com/meta)          ACCEPT
        ├── resolved IPs: registry.npmjs.org, api.anthropic.com,
        │     api.figma.com, mcp.linear.app, statsig/sentry,
        │     vscode server hosts                                  ACCEPT
        ├── host gateway (host.docker.internal): Rails/API +
        │     pg/redis/es/memcached running on the host            ACCEPT
        └── everything else                                        REJECT
```

- **Writes are governed by credential scope, not the network.** GraphQL and all
  HTTP methods reach the allowed hosts; what you can *do* there is bounded by the
  tokens you provide. GitHub MCP isn't used here — `gh`/REST/GraphQL cover it.
- **Local servers run on the host** (this repo's `docker-compose.yml` runs only
  pg/redis/es/memcached; Rails + API run on the host). They're reached via
  `host.docker.internal`. mitmproxy isn't involved, so raw TCP (Postgres/Redis)
  works fine.

## Files

| File | Purpose |
|---|---|
| `devcontainer.json` | Build config, caps (`NET_ADMIN`/`NET_RAW`), `host-gateway`, runs the firewall on `postStart`. |
| `Dockerfile` | Ubuntu base + iptables/ipset/aggregate/dnsutils/jq, Node LTS, GitHub CLI, Claude Code. |
| `init-firewall.sh` | Default-DROP egress allowlist (fork of Anthropic's, + `api.figma.com` + host-gateway). |

## Using it

### 1. Provide credentials (once, via a gitignored env file)

Create `.devcontainer/.env.local` from the template — it's gitignored and loaded
into the container on every launch (`--env-file` in `devcontainer.json`), so you
set the tokens once and never export them again:

```bash
cp .devcontainer/.env.local.example .devcontainer/.env.local
# then edit .env.local and fill in the two values below
```

- `CLAUDE_CODE_OAUTH_TOKEN` — Anthropic auth for Claude Code. Generate on the
  HOST with `claude setup-token` (a subscription token, not an API key).
- `GH_TOKEN` — a **dedicated read-only** GitHub fine-grained PAT. **Do not** reuse
  your normal write-capable `gh` login — see credential hygiene below.

**Generating the read-only GitHub PAT:** github.com → Settings → Developer
settings → Personal access tokens → **Fine-grained tokens** → Generate new token.
Set **Resource owner** = the repo's owner (e.g. the `inaturalist` org — org
fine-grained tokens may need org approval), **Repository access** = Only select
repositories → pick the repo(s), and under **Repository permissions** set
**Read-only** for: Contents, Metadata (required), Pull requests, Issues, Actions.
No write permissions. Copy the `github_pat_…` value into `.env.local`.

> Prefer Keychain over a plaintext file? You can instead store the tokens in the
> macOS Keychain and export them in your shell profile via
> `export GH_TOKEN=$(security find-generic-password -s cc-sandbox-gh -w)` — then
> drop the `--env-file` arg. The env file is simpler; Keychain avoids on-disk
> secrets.

### 2. Launch the container

**VS Code:** install the *Dev Containers* extension
(`ms-vscode-remote.remote-containers`), then Command Palette →
**Dev Containers: Reopen in Container**. (This extension is MS-licensed and does
**not** run in Cursor or other forks — use the CLI there.)

**CLI (editor-independent, works everywhere):**
```bash
npm install -g @devcontainers/cli
devcontainer up   --workspace-folder .
devcontainer exec --workspace-folder . claude
```

### 3. MCPs

Connect only **read-only** MCPs (see credential hygiene below). GitHub is covered
by `gh`/REST/GraphQL — no GitHub MCP needed.

**Linear (read-only):** Linear's official remote MCP (`https://mcp.linear.app/mcp`,
Streamable HTTP) accepts an API key as a Bearer header, so no interactive OAuth is
needed. Generate a **read-only** key (`LINEAR_API_KEY` in `.env.local`, see above),
then register the server **inside the container**:

```bash
claude mcp add --transport http linear https://mcp.linear.app/mcp \
  --header "Authorization: Bearer $LINEAR_API_KEY"
```

A read-only key also enforces this repo's "don't create issues" rule (see root
`CLAUDE.md`) at the credential layer — without `Create issues`/`Write` scope,
Linear writes simply aren't possible.

## What this sandbox stops — and what it doesn't

**It stops (accidental / casual egress):**
- Reaching arbitrary external hosts — only the allowlisted hosts resolve+connect;
  everything else is dropped.
- Tools/processes inadvertently phoning home to non-allowlisted endpoints.
- Combined with read-only credentials: accidental writes to GitHub/Figma/etc.

**It does NOT stop (a determined / adversarial exfiltrator):**
- **DNS exfiltration** — port 53 is open so hostnames resolve; data can be
  encoded into lookups like `<base64>.attacker.com` and leave via the resolver.
  Neither iptables nor an HTTP proxy closes this.
- **Exfil through allowed hosts** — data encoded in GET paths/query strings to an
  allowlisted host, or (if a write-capable credential exists) pushed into a
  gist / repo / issue comment on github.com.
- **Shared CDN IPs** — allowlisting a CDN IP for github.com also reaches other
  sites co-hosted on that IP, addressed via a different Host/SNI.

**Threat model:** this is sized to *prevent accidents and casual leakage*
(including basic prompt-injection / dependency mishaps), **not** to contain an
actively adversarial agent. The real protection against writes/leaks is
credential hygiene — keep every token/cred in the container read-only and keep
high-value secrets out of the box. If you need to contain a determined
exfiltrator, this design is insufficient: you'd need egress only via a
DNS-filtering proxy, no raw port 53, and no broad CDN IP ranges.

### Known fragilities (robustness gaps, not yet hardened)

These don't widen the threat model but can break connectivity or fail in
surprising ways. Tracked in `HANDOFF.md`.

- **IPv6 GitHub ranges hard-fail the firewall.** `api.github.com/meta` returns
  IPv6 CIDRs in `.web/.api/.git`. The CIDR validator in `init-firewall.sh` only
  accepts IPv4 and runs `exit 1` on anything else — so a single IPv6 range would
  abort the entire script and leave `postStart` failed. It works today only
  because `aggregate -q` happens to drop IPv6; if that feed or tool behavior
  shifts, the firewall silently stops coming up. Filter IPv6 out before the loop
  rather than treating it as fatal.
- **DNS is UDP-only.** Only `udp/53` is allowed. DNS responses large enough to
  fall back to `tcp/53` are dropped — a rare but real cause of resolution
  failures for the allowlisted domains.
- **No SSH egress (by design as of this revision).** Port 22 is closed; `gh`/git
  use `GH_TOKEN` over HTTPS. If you ever need git-over-SSH, scope it to the
  allowlist (see the commented snippet in `init-firewall.sh`) — do **not**
  re-add a blanket `--dport 22 ACCEPT`, which reopens an exfil/tunnel path to
  any host.
- **IP-based allowlist goes stale.** CDN-backed hosts (npm/Anthropic/Figma/
  Linear) rotate IPs and are resolved only at container start; restart/rebuild
  to re-resolve when their calls start failing.

## Operational notes / manual steps

- **Credential hygiene (critical):** every token/cred in the container must be
  read-only — read-only GitHub PAT, read-only Linear/Figma keys, and no
  write-capable `gh`/git/SSH creds. This, not the network, is what prevents writes.
- **Figma remote MCP host:** if the hosted Figma MCP endpoint host differs from
  `api.figma.com`, add it to the domain loop in `init-firewall.sh`.
- **CDN IP staleness:** if Figma/npm/Linear/Anthropic calls start failing, rebuild
  or restart the container to re-resolve IPs (the allowlist is IP-based).
- **Ruby/Rails runtime is not in the image** by design (the app runs on the
  host). Extend the `Dockerfile` if you want to run specs inside the container.
- **Editor connectivity:** if Cursor/VS Code can't connect, its server is being
  fetched in-container — the `vscode.*` hosts are already in the allowlist; add
  any others your setup needs.
- **`claude` shows the onboarding wizard (theme / "Select login method"):**
  - The interactive TUI skips onboarding only when `~/.claude.json` has
    `hasCompletedOnboarding: true`. The image bakes this in, but the file is
    created at **image build** — if you only restarted the container, rebuild the
    image: `devcontainer up --build --remove-existing-container` (or VS Code →
    "Dev Containers: Rebuild Container"). Confirm with
    `cat ~/.claude.json` inside the container.
  - If it still asks to **log in** specifically, the token isn't reaching the
    process. `--env-file` is read at container **create/start**, so fill in
    `.env.local` *before* launching and recreate after editing. Verify with
    `printenv CLAUDE_CODE_OAUTH_TOKEN`; ensure no `ANTHROPIC_API_KEY` is set (it
    takes precedence); and confirm you're running `claude` *inside* the container,
    not on the host. `claude -p "hi"` is a quick headless auth check.

## Verification

From a terminal inside the container after it builds:

```bash
curl -sS https://api.github.com/zen                         # 200 (GitHub allowed)
curl -sSm5 https://example.com                              # blocked / rejected (not allowlisted)
gh auth status && gh pr list -R inaturalist/inaturalist     # works (GraphQL allowed)
curl -sS http://host.docker.internal:3000/ | head           # reaches host Rails
PGPASSWORD=inaturalist psql -h host.docker.internal -U inaturalist -c '\l'   # host pg
claude -p "say hi"                                          # model call succeeds
sudo iptables -L OUTPUT -n                                  # default-DROP + ACCEPT rules
```

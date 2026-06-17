FROM mcr.microsoft.com/devcontainers/base:noble

# Tooling for the egress firewall (iptables/ipset/aggregate), DNS resolution
# (dnsutils -> dig, plus getent), JSON parsing (jq), and fetching (curl/gnupg).
# Installed at build time when the network is open — the firewall only applies
# at container start.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      iptables \
      ipset \
      aggregate \
      dnsutils \
      jq \
      curl \
      gnupg \
      ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Node LTS — for Claude Code and the repo's JS tooling.
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# GitHub CLI.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/*

# Claude Code itself, installed into a vscode-owned prefix so auto-update works.
# npm's default global prefix (/usr) is root-owned; installing there means the
# vscode user can't write to it when Claude Code tries to self-update.
ENV NPM_CONFIG_PREFIX=/home/vscode/.npm-global
ENV PATH=/home/vscode/.npm-global/bin:$PATH
RUN mkdir -p /home/vscode/.npm-global \
 && chown -R vscode:vscode /home/vscode/.npm-global
USER vscode
RUN npm install -g @anthropic-ai/claude-code playwright
USER root
# Install system-level .so dependencies Playwright's bundled Chromium needs
# (libnss3, libatk, etc.). The Chromium binary itself is installed per-user in
# postCreateCommand using the project's pinned @playwright/test revision.
RUN npx playwright install-deps chromium
USER vscode
RUN npx playwright install chromium
USER root

# Ruby via rbenv — version pinned to match .ruby-version in the repo.
ENV RBENV_ROOT=/home/vscode/.rbenv
ENV PATH=/home/vscode/.rbenv/bin:/home/vscode/.rbenv/shims:$PATH
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git libssl-dev libreadline-dev zlib1g-dev \
      autoconf bison build-essential libyaml-dev libpq-dev shared-mime-info \
      libncurses5-dev libffi-dev libgdbm-dev libgdbm-compat-dev \
 && rm -rf /var/lib/apt/lists/*

# PostgreSQL 18 client for pg_dump — Noble's default postgresql-client is 16,
# which can't dump a PG18 server.
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] https://apt.postgresql.org/pub/repos/apt noble-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client-18 \
 && rm -rf /var/lib/apt/lists/*
USER vscode
RUN git clone https://github.com/rbenv/rbenv.git $RBENV_ROOT \
 && git clone https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build \
 && rbenv install 3.3.7 \
 && rbenv global 3.3.7 \
 && gem install bundler --no-document \
 && bundle config set --global path /workspace/.devcontainer/gems \
 && bundle config set --global build.ed25519 "--with-cflags='-include stdbool.h'"
USER root

# Egress allowlist script, applied at container start (see devcontainer.json).
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

# Pre-seed Claude Code config so the interactive first-run onboarding (theme +
# login wizard) is skipped — auth comes from CLAUDE_CODE_OAUTH_TOKEN. The home
# dir is recreated on every rebuild, so this is baked into the image rather than
# left to a one-time login.
RUN echo '{"hasCompletedOnboarding": true}' > /home/vscode/.claude.json \
 && chown vscode:vscode /home/vscode/.claude.json

# The base image already grants the `vscode` user passwordless sudo, which the
# postStartCommand relies on to apply the firewall. Default caps are retained
# (NET_ADMIN/NET_RAW are added via runArgs) — we deliberately do NOT cap-drop ALL,
# which would neuter setuid sudo.

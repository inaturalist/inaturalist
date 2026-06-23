#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting

# Egress allowlist for the Claude Code sandbox.
#
# Forked from anthropics/claude-code .devcontainer/init-firewall.sh with:
#   - api.figma.com added to the allowed domain list
#   - an explicit host.docker.internal gateway allowance (so the container can
#     reach the host-run Rails/API servers and backing services pg/redis/es/
#     memcached). The upstream default-route /24 rule covers this on Linux, but
#     NOT reliably on Docker Desktop (macOS), where the gateway sits elsewhere.
#
# Policy: default-DROP egress, ACCEPT only loopback, DNS, SSH, established
# connections, the host network/gateway, GitHub's published ranges, and the
# resolved IPs of the allowed domains. Everything else is REJECTed.
#
# NOTE: this allowlists by IP. CDN-backed hosts (figma/npm/anthropic/claude.ai) rotate
# IPs and publish no ranges, so they're resolved at start and can go stale —
# rebuild/restart to re-resolve. See README.md "What this sandbox stops".

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# First allow DNS and localhost before any restrictions
# Allow outbound DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
# Allow inbound DNS responses
iptables -A INPUT -p udp --sport 53 -j ACCEPT
# No SSH egress: gh/git use GH_TOKEN over HTTPS (GitHub's ranges are in the
# allowlist below), so port 22 is pure attack surface here. A blanket
# --dport 22 ACCEPT would let any process tunnel/exfil over SSH to ANY host,
# bypassing the IP allowlist. If git-over-SSH is ever needed, gate it on the
# allowlist instead of opening 22 globally:
#   iptables -A OUTPUT -p tcp --dport 22 -m set --match-set allowed-domains dst -j ACCEPT
# Allow localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Fetch GitHub meta information and aggregate + add their IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add -exist allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Resolve and add other allowed domains
for domain in \
    "registry.npmjs.org" \
    "rubygems.org" \
    "index.rubygems.org" \
    "api.anthropic.com" \
    "claude.ai" \
    "api.figma.com" \
    "mcp.linear.app" \
    "sentry.io" \
    "statsig.anthropic.com" \
    "statsig.com" \
    "marketplace.visualstudio.com" \
    "vscode.blob.core.windows.net" \
    "update.code.visualstudio.com"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}' || true)
    if [ -z "$ips" ]; then
        # Non-fatal: a single flaky/retired telemetry host (or a CNAME-only
        # record) must not wipe out the whole allowlist. Essential connectivity
        # is verified at the end of this script.
        echo "WARNING: could not resolve $domain — skipping"
        continue
    fi

    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        ipset add -exist allowed-domains "$ip"
    done < <(echo "$ips")
done

# Explicitly allow the Docker host gateway so the container can reach the
# host-run Rails/API servers and backing services (pg:5432, redis:6379,
# es:9200, memcached:11211). On Docker Desktop the gateway is not in
# HOST_NETWORK below, so resolve host.docker.internal (populated into /etc/hosts
# via --add-host=host.docker.internal:host-gateway) and allow it directly.
echo "Resolving host.docker.internal..."
host_gw_ips=$(getent ahostsv4 host.docker.internal | awk '{print $1}' | sort -u || true)
if [ -n "$host_gw_ips" ]; then
    while read -r gip; do
        [ -z "$gip" ] && continue
        echo "Adding host gateway $gip"
        ipset add allowed-domains "$gip" 2>/dev/null || true
    done < <(echo "$host_gw_ips")
else
    echo "WARNING: host.docker.internal did not resolve; host passthrough (Rails/pg/redis/es) may fail"
fi

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

# Set up remaining iptables rules
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Set default policies to DROP first
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# First allow established connections for already approved traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Then allow only specific outbound traffic to allowed domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Explicitly REJECT all other outbound traffic for immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

# Verify GitHub API access
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi

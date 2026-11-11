# Private point-count workflow

Status: accepted scope; implemented private pilot. Date: October 25, 2026.
Steve approved the five-minute, 50-metre, single-observer specification and
requested a verified baseline and a small end-to-end Rails workflow.

## Problem and alternatives

We need to exercise the survey backend with a real protocol while preserving
ordinary observations, Trips, taxonomy and upstream interfaces. Options were to
expand the existing Trip editor, add narrowly scoped private Rails pages using
the existing survey services, or first build an API/mobile workflow. Another
choice was new protocol-specific columns versus existing typed measurements.

## Decision and rationale

Use `/point_counts` for the small owner-only Rails workflow and existing typed
measurements for the concrete protocol. This isolates private scientific records
from Trip's public presentation and avoids changing its discovery/presence-absence
semantics. No tables, dependencies, public APIs or Trip behavior are added here.
Trips remain optionally composable through the existing backend; this UI does
not need a Trip to create a visit.

Install one explicitly identified protocol/version through an operator task,
owned by an existing user. GET requests never create or publish protocols.
Use server-controlled ownership, privacy and protocol identity. Every read and
write scopes to the signed-in owner; participants are not collaborators. Existing
observations must belong to that owner to be linked. Do not serialize them or
copy their location into the survey UI.

Preserve actual effort on deviations. Separate method compliance from complete
reporting and terminal lifecycle. Finalization freezes the scientific record;
correction is explicit void-and-replace with a written reference. Reuse active,
owner-controlled private stations; no station editing or sharing is exposed.

## Consequences and boundaries

The complete specification and implementation boundaries are in
[the protocol document](../protocols/stationary-bird-point-count-v1.md).
Pilot-specific cross-field rules live in an authorized operation class; existing
SQL constraints remain the scientific integrity foundation. Privileged generic
services and SQL can bypass the extra pilot application rules. Broader enforcement
would require a separately reviewed additive migration, not rewriting v0.2 SQL.

Use explicit savepoint transactions and row locks around mutations. Rails 6.1's
`with_lock` argument is a lock clause, not transaction options; the new operation
boundary uses `transaction(requires_new: true)` followed by `lock!`.

Keep all visits private, omit analytics and maps, filter form parameters and
prevent caching/referrer disclosure. No new deletion or anonymization policy is
introduced. Existing restrictive user foreign keys remain; account erasure and
public/sensitive-location disclosure must be resolved before production exposure.
The local pilot is not evidence of readiness for public deployment.

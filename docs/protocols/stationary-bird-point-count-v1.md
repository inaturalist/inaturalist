# Stationary Bird Point Count — version 1

Status: approved by Steve for the first private pilot, October 25, 2026.
This is a project-specific protocol, not a claim of equivalence to BBS or eBird.
The executable definition is `Surveys::PointCountProtocol` and is installed as a
published, immutable SurveyProtocolVersion. No existing taxonomy is replaced.

## Field method

- Target all wild birds using habitat within a 50-metre horizontal radius of a
  fixed, named station. Apply the boundary to both visual and auditory detections.
- One active observer. A companion may take notes but must not add detections.
- Arrive quietly and wait one minute before starting; exclude this from effort.
- Count for five uninterrupted minutes, remaining at the station. Binoculars are
  allowed; playback, pishing, baiting and approaching birds are excluded.
- Prefer the first three hours after sunrise. Avoid precipitation and strong wind.
  Record actual times, time zone, precipitation, wind and disruptive noise.
- Count distinct individuals once, including birds both heard and seen. Use the
  minimum confidently distinguished and note uncertainty. Include aerial foraging;
  exclude mere flyovers. Outside-radius and uncertain-distance birds belong in notes.
- Identify only as precisely as justified, using existing iNaturalist taxa. Aves
  is available for an unidentified bird. Report positive integer totals per taxon,
  with detection method seen, heard or both.
- Photographs and recordings are optional. Link existing observations as evidence;
  do not create a duplicate observation or infer an organism's position from the station.

## Effort, compliance and completeness

Two independent answers are required before completing data entry:

1. Was the prescribed method followed for five uninterrupted minutes?
2. Was every in-scope detection reported, including unidentified birds?

Actual elapsed effort is calculated from start/end times. A compliant visit must
have exactly 300 seconds, no precipitation and no strong wind. Other field rules
are observer attestations. Interrupted or nonconforming visits remain valid
records: select No for method compliance and supply a deviation reason. Do not
inflate duration to 300 seconds. An incomplete report can also be finalized and
remains explicitly incomplete. Finalization freezes the scientific record; it
is not a declaration of protocol compliance or complete coverage.

A completed visit with positive effort and no detections is supported. No species
absence rows are generated. The bird-group assessment never enables absence
reporting in this pilot. Counts represent detections, not a population census or
density estimate. Local time-zone conversion is supported; no sunrise calculation
or independent verification of observer distance/behavior is performed.

## Stored representation and enforcement

The existing 13-table schema is sufficient. There is one protocol version, one
required Aves group target, one private site/point station per newly created station,
one event per visit, one observer participant, and one effort row. Repeated visits
reference the same station and keep separate historical event geometry snapshots.
Retired stations are not offered for new visits.

Versioned measurement definitions store:

| Key | Type / vocabulary |
| --- | --- |
| radius_meters | Numeric, metres, fixed at 50 |
| method_followed | Boolean; false is a recorded answer |
| all_detections_reported | Boolean, separate from method compliance |
| deviation_reason | Text, conditionally required by workflow |
| precipitation | none / rain / snow |
| wind | calm / light / moderate / strong |
| noise | none / intermittent / continuous |
| detection_method | seen / heard / both, required on each detection |

Existing database constraints enforce types, vocabularies, radius range,
required measurements, and historical immutability. `Surveys::PointCount` adds
owner authorization, bird-subtree membership, whole-number totals, one total per
taxon, actual duration, conditional compliance, and deviation validation. These
pilot-specific rules are enforced at the application operation boundary; direct
SQL and the generic survey services remain privileged internal interfaces and do
not enforce all pilot rules. No generalized protocol rule language was added.

## Trying the workflow

Apply normal pending migrations to a backed-up development database. Install once
with an existing local user as protocol owner, from `web` with the workspace
environment and candidate database selection loaded:

```bash
OWNER_ID=1 bundle exec rake surveys:install_point_count
```

The installer is transactional and retry-safe and never rewrites a published
version. If its definition needs scientific changes, publish a new version rather
than editing this one. The current UI explicitly uses version 1.

Open `/point_counts`, sign in normally, and:

1. Create a visit at a new named station with coordinates, or reuse your station.
2. Enter actual start/end times and time zone, weather, both assessments and notes;
   select **Save effort and assessment**.
3. Search local scientific/common names, choose a bird, and add its total and
   detection method. Optionally link one of your existing observation IDs. The
   local reference dataset primarily contains scientific names, so common-name
   searches may not return a match. Aves is always available.
4. Review and complete. Zero detections and explained deviations are supported.
5. For another visit, select **New visit at this station**. For a correction,
   void the completed visit with a reason and create a replacement; include the
   original UUID in its notes. No automatic correction link is inferred.

Only the owner can read or mutate the pilot pages. Participants and protocol
ownership grant no access to someone else's visit. Requests accept HTML only;
there is no new public API, search index, sharing or export feature. Links to
observations preserve the observation's own visibility and ownership. A survey
being private does not make an already-public observation private.

This English-language pilot uses normal iNaturalist sign-in, CSRF protection and
Rails forms. Responses are noncacheable and noindex, and send referrers only within the same origin. The layout
loads no maps, third-party assets or analytics. The form payload is filtered from
Rails parameter logs. Database administrators and privileged SQL statement logs
remain outside this owner-facing disclosure boundary.

Account erasure/anonymization remains unresolved: existing survey references can
block physical deletion. This prototype does not change that policy and is not
ready for public production deployment. Sharing, general protocol authoring,
offline/mobile capture, and media upload are outside this milestone.

// Feature flags for the front end.
//
// Flags are evaluated server-side, per actor, by FeatureFlagging ( lib/feature_flagging.rb )
// and injected into the inline CONFIG payload by ApplicationHelper#feature_flags_json. The
// browser never sees targeting rules -- percentages, actor lists, or the names of flags kept
// out of FeatureFlagging::CLIENT_FLAGS -- only the resolved booleans for this visitor.
//
// A flag must be listed in CLIENT_FLAGS on the Ruby side to be readable here. Anything else,
// including a typo, reads as off.
//
//   import featureFlagEnabled from "../../shared/feature_flags";
//   if ( featureFlagEnabled( "some_flag" ) ) { ... }
//
// CONFIG is read on every call rather than captured at import time, so this cannot be broken
// by script or bundle ordering.
export default function featureFlagEnabled( key ) {
  return !!(
    typeof CONFIG !== "undefined"
    && CONFIG
    && CONFIG.feature_flags
    && CONFIG.feature_flags[key]
  );
}

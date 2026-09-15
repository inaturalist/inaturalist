// Read CONFIG on every call, not at import, to avoid bundle ordering issues.
export default function featureFlagEnabled( key ) {
  return !!(
    typeof CONFIG !== "undefined"
    && CONFIG
    && CONFIG.feature_flags
    && CONFIG.feature_flags[key]
  );
}

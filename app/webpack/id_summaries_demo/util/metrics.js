import inatjs from "inaturalistjs";

export const publicMetricsConfig = ( typeof window !== "undefined" && window.ID_SUMMARY_PUBLIC_METRICS ) || {};

export const publicMetricKeys = Object.keys( publicMetricsConfig );

export const hasPublicMetrics = publicMetricKeys.length > 0;

export const metricLabel = metric => publicMetricsConfig?.[metric]?.label || metric;

export const buildEmptyMetricCounts = () => {
  const counts = {};
  publicMetricKeys.forEach( key => {
    counts[key] = { up: 0, down: 0 };
  } );
  return counts;
};

const buildEmptyMetricState = () => ( {
  counts: buildEmptyMetricCounts(),
  userVote: {}
} );

export const fetchSummaryMetricsCounts = async ( {
  taxonSummaryUuid,
  summaryId,
  options = {}
} = {} ) => {
  if (
    !hasPublicMetrics
    || !taxonSummaryUuid
    || !summaryId
  ) {
    return buildEmptyMetricState();
  }
  try {
    const taxonIdSummariesAPI = inatjs?.taxon_id_summaries;
    if ( !taxonIdSummariesAPI || typeof taxonIdSummariesAPI.summaryQualityMetrics !== "function" ) {
      throw new Error( "inatjs.taxon_id_summaries.summaryQualityMetrics unavailable" );
    }
    const params = {
      uuid: taxonSummaryUuid,
      id: summaryId,
      fields: "id,metric,agree,user_id"
    };
    const response = await taxonIdSummariesAPI.summaryQualityMetrics(
      params,
      options
    );
    const data = buildEmptyMetricState();
    const { counts, userVote } = data;
    const currentUserId = ( typeof window !== "undefined"
      && window.CURRENT_USER
      && window.CURRENT_USER.id ) || null;
    const results = Array.isArray( response?.results ) ? response.results : [];
    results.forEach( metric => {
      const key = metric?.metric;
      if ( !key || !counts[key] ) { return; }
      if ( metric?.agree === false ) {
        counts[key].down += 1;
      } else {
        counts[key].up += 1;
      }
      if ( currentUserId && metric?.user_id === currentUserId ) {
        userVote[key] = metric?.agree === false ? -1 : 1;
      }
    } );
    return data;
  } catch ( error ) {
    // eslint-disable-next-line no-console
    console.warn( "Failed to fetch summary metrics", error );
    return buildEmptyMetricState();
  }
};

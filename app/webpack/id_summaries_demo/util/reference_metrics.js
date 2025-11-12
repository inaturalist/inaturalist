import inatjs from "inaturalistjs";

export const referenceMetricsConfig = ( typeof window !== "undefined"
  && window.ID_SUMMARY_REFERENCE_METRICS ) || {};

export const referenceMetricKeys = Object.keys( referenceMetricsConfig );

export const hasReferenceMetrics = referenceMetricKeys.length > 0;

const interpolateLabel = ( template, context = {} ) => {
  if ( typeof template !== "string" ) { return ""; }
  const speciesLabel = context?.speciesLabel;
  if ( speciesLabel ) {
    return template.replace( /%\{taxon\}/g, speciesLabel );
  }
  return template.replace( /%\{taxon\}/g, "" ).trim();
};

export const referenceMetricLabel = ( metric, context = {} ) => {
  const template = referenceMetricsConfig?.[metric]?.label || metric;
  return interpolateLabel( template, context );
};

export const buildEmptyReferenceMetricCounts = () => {
  const counts = {};
  referenceMetricKeys.forEach( key => {
    counts[key] = { up: 0, down: 0 };
  } );
  return counts;
};

const buildEmptyReferenceMetricState = () => ( {
  counts: buildEmptyReferenceMetricCounts(),
  userVote: {}
} );

export const fetchReferenceMetricsCounts = async ( {
  taxonSummaryUuid,
  summaryId,
  referenceId,
  options = {}
} = {} ) => {
  if (
    !hasReferenceMetrics
    || !taxonSummaryUuid
    || !summaryId
    || !referenceId
  ) {
    return buildEmptyReferenceMetricState();
  }
  try {
    const api = inatjs?.taxon_id_summaries;
    if ( !api || typeof api.referenceQualityMetrics !== "function" ) {
      throw new Error( "inatjs.taxon_id_summaries.referenceQualityMetrics unavailable" );
    }
    const params = {
      uuid: taxonSummaryUuid,
      id: summaryId,
      reference_id: referenceId,
      fields: "id,metric,agree,user_id"
    };
    const response = await api.referenceQualityMetrics( params, options );
    const data = buildEmptyReferenceMetricState();
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
    console.warn( "Failed to fetch reference metrics", error );
    return buildEmptyReferenceMetricState();
  }
};

export default {
  referenceMetricsConfig,
  referenceMetricKeys,
  hasReferenceMetrics,
  referenceMetricLabel,
  buildEmptyReferenceMetricCounts,
  fetchReferenceMetricsCounts
};

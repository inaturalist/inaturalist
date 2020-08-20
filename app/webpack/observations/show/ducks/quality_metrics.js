import inatjs from "inaturalistjs";

const SET_QUALITY_METRICS = "obs-show/quality_metrics/SET_QUALITY_METRICS";

export default function reducer( state = [], action ) {
  switch ( action.type ) {
    case SET_QUALITY_METRICS:
      return action.metrics;
    default:
      // nothing to see here
  }
  return state;
}

export function setQualityMetrics( metrics ) {
  return {
    type: SET_QUALITY_METRICS,
    metrics
  };
}

export function fetchQualityMetrics( options = {} ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { testingApiV2 } = s.config;
    const observation = options.observation || getState( ).observation;
    if ( !observation ) { return null; }
    const params = { id: observation.id, ttl: -1 };
    if ( testingApiV2 ) {
      params.id = observation.uuid;
      params.fields = {
        agree: true,
        id: true,
        metric: true,
        user: {
          id: true,
          login: true,
          icon_url: true
        }
      };
    }
    return inatjs.observations.qualityMetrics( params ).then( response => {
      dispatch( setQualityMetrics( response.results ) );
    } ).catch( ( ) => { } );
  };
}

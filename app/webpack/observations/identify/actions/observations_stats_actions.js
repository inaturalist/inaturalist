import iNaturalistJS from "inaturalistjs";
import { paramsForSearch } from "../reducers/search_params_reducer";

const UPDATE_OBSERVATIONS_STATS = "update_observations_stats";

function updateObservationsStats( stats ) {
  return {
    type: UPDATE_OBSERVATIONS_STATS,
    stats
  };
}

function fetchObservationsStats( ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const apiParams = Object.assign( {
      viewer_id: s.config.currentUser ? s.config.currentUser.id : null,
      ttl: -1
    }, paramsForSearch( s.searchParams.params ) );
    const reviewedParams = Object.assign( {}, apiParams, { reviewed: true } );
    iNaturalistJS.observations.search( reviewedParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          reviewed: response.total_results
        } ) );
      } );
    const anyReviewedParams = Object.assign( {}, apiParams, { reviewed: "any" } );
    iNaturalistJS.observations.search( anyReviewedParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          total: response.total_results
        } ) );
      } );
  };
}

export {
  UPDATE_OBSERVATIONS_STATS,
  updateObservationsStats,
  fetchObservationsStats
};

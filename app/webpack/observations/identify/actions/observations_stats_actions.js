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
      viewer_id: s.config.currentUser ? s.config.currentUser.id : null
    }, paramsForSearch( s.searchParams ) );
    const needsIdParams = Object.assign( {}, apiParams, { quality_grade: "needs_id" } );
    iNaturalistJS.observations.search( needsIdParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          needsId: response.total_results
        } ) );
      } );
    const researchParams = Object.assign( {}, apiParams, { quality_grade: "research" } );
    iNaturalistJS.observations.search( researchParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          research: response.total_results
        } ) );
      } );
    const casualParams = Object.assign( {}, apiParams, { quality_grade: "casual" } );
    iNaturalistJS.observations.search( casualParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          casual: response.total_results
        } ) );
      } );
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

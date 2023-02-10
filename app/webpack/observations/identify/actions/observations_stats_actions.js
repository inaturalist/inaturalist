import iNaturalistJS from "inaturalistjs";
import { paramsForSearch } from "../reducers/search_params_reducer";

const UPDATE_OBSERVATIONS_STATS = "update_observations_stats";

function updateObservationsStats( stats ) {
  return {
    type: UPDATE_OBSERVATIONS_STATS,
    stats
  };
}

function resetObservationsStats( ) {
  return dispatch => {
    dispatch( updateObservationsStats( {
      status: null
    } ) );
  };
}

function fetchObservationsStats( force = false ) {
  return function ( dispatch, getState ) {
    const s = getState();
    if ( !force && (
      s.observationsStats.status === "loading" || s.observationsStats.status === "loaded"
    ) ) {
      return;
    }
    const apiParams = {
      viewer_id: s.config.currentUser ? s.config.currentUser.id : null,
      ttl: -1,
      ...paramsForSearch( s.searchParams.params )
    };
    const reviewedParams = {
      ...apiParams,
      reviewed: true,
      page: 1,
      per_page: 0
    };
    dispatch( updateObservationsStats( {
      status: "loading"
    } ) );
    iNaturalistJS.observations.search( reviewedParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          reviewed: response.total_results,
          status: "loaded"
        } ) );
      } );
    const anyReviewedParams = {
      ...apiParams,
      page: 1,
      per_page: 0
    };
    iNaturalistJS.observations.search( anyReviewedParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          total: response.total_results,
          status: "loaded"
        } ) );
      } );
  };
}

function incrementReviewed( ) {
  return function ( dispatch, getState ) {
    const state = getState( ).observationsStats;
    if ( state.reviewed < state.total ) {
      dispatch( updateObservationsStats( {
        reviewed: state.reviewed + 1
      } ) );
    }
  };
}

function decrementReviewed( ) {
  return function ( dispatch, getState ) {
    const state = getState( ).observationsStats;
    if ( state.reviewed > 0 ) {
      dispatch( updateObservationsStats( {
        reviewed: state.reviewed - 1
      } ) );
    }
  };
}

export {
  UPDATE_OBSERVATIONS_STATS,
  updateObservationsStats,
  fetchObservationsStats,
  incrementReviewed,
  decrementReviewed,
  resetObservationsStats
};

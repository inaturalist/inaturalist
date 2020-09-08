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
    const apiParams = Object.assign(
      {
        viewer_id: s.config.currentUser ? s.config.currentUser.id : null,
        ttl: -1
      },
      paramsForSearch( s.searchParams.params ),
      {
        order: "",
        order_by: ""
      }
    );
    const reviewedParams = Object.assign( {}, apiParams, {
      reviewed: true,
      page: 1,
      per_page: 0
    } );
    iNaturalistJS.observations.search( reviewedParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          reviewed: response.total_results
        } ) );
      } );
    const anyReviewedParams = Object.assign( {}, apiParams, {
      reviewed: "any",
      page: 1,
      per_page: 0
    } );
    iNaturalistJS.observations.search( anyReviewedParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          total: response.total_results
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
  decrementReviewed
};

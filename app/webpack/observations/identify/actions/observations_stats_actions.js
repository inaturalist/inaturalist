import iNaturalistJS from "inaturalistjs";

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
      verifiable: true,
      reviewed: false,
      viewer_id: s.config.currentUser ? s.config.currentUser.id : null
    }, s.searchParams );
    apiParams.quality_grade = "needs_id";
    iNaturalistJS.observations.search( apiParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          needsId: response.total_results
        } ) );
      } );
    apiParams.quality_grade = "research";
    iNaturalistJS.observations.search( apiParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          research: response.total_results
        } ) );
      } );
    apiParams.quality_grade = "casual";
    iNaturalistJS.observations.search( apiParams )
      .then( response => {
        dispatch( updateObservationsStats( {
          casual: response.total_results
        } ) );
      } );
  };
}

export {
  UPDATE_OBSERVATIONS_STATS,
  updateObservationsStats,
  fetchObservationsStats
};

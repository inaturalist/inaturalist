import iNaturalistJS from "inaturalistjs";
import { fetchObservationsStats } from "./observations_stats_actions";

const RECEIVE_OBSERVATIONS = "receive_observations";
const UPDATE_OBSERVATION_IN_COLLECTION = "update_observation_in_collection";

function receiveObservations( results ) {
  return Object.assign( { type: RECEIVE_OBSERVATIONS }, results );
}

function fetchObservations( ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const currentUserId = s.config.currentUser ? s.config.currentUser.id : null;
    const apiParams = Object.assign( { viewer_id: currentUserId }, s.searchParams );
    return iNaturalistJS.observations.search( apiParams )
      .then( response => {
        const obs = response.results.map( ( o ) => {
          if ( currentUserId && o.reviewed_by.indexOf( currentUserId ) > -1 ) {
            // eslint complains about this, but if you create a new object
            // with Object.assign you lose all the Observation model stuff
            o.reviewedByCurrentUser = true;
          }
          return o;
        } );
        dispatch( receiveObservations( {
          totalResults: response.total_results,
          page: response.page,
          perPage: response.per_page,
          totalPages: Math.ceil( response.total_results / response.per_page ),
          results: obs
        } ) );
        dispatch( fetchObservationsStats( ) );
      } );
  };
}

function updateObservationInCollection( observation, changes ) {
  return {
    type: UPDATE_OBSERVATION_IN_COLLECTION,
    observation,
    changes
  };
}

export {
  RECEIVE_OBSERVATIONS,
  UPDATE_OBSERVATION_IN_COLLECTION,
  receiveObservations,
  fetchObservations,
  updateObservationInCollection
};

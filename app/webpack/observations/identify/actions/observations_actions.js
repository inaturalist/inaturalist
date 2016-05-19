import _ from "lodash";
import iNaturalistJS from "inaturalistjs";
import { fetchObservationsStats } from "./observations_stats_actions";
import { fetchIdentifiers } from "./identifiers_actions";
import { paramsForSearch } from "../reducers/search_params_reducer";

const RECEIVE_OBSERVATIONS = "receive_observations";
const UPDATE_OBSERVATION_IN_COLLECTION = "update_observation_in_collection";
const UPDATE_ALL_LOCAL = "update_all_local";

function receiveObservations( results ) {
  return Object.assign( { type: RECEIVE_OBSERVATIONS }, results );
}

function fetchObservations( ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const currentUserId = s.config.currentUser ? s.config.currentUser.id : null;
    const apiParams = Object.assign( { viewer_id: currentUserId },
      paramsForSearch( s.searchParams ) );
    return iNaturalistJS.observations.search( apiParams )
      .then( response => {
        let obs = response.results;
        if ( currentUserId ) {
          obs = response.results.map( ( o ) => {
            if ( o.reviewed_by.indexOf( currentUserId ) > -1 ) {
              // eslint complains about this, but if you create a new object
              // with Object.assign you lose all the Observation model stuff
              o.reviewedByCurrentUser = true;
            }
            return o;
          } );
        }
        dispatch( receiveObservations( {
          totalResults: response.total_results,
          page: response.page,
          perPage: response.per_page,
          totalPages: Math.ceil( response.total_results / response.per_page ),
          results: obs
        } ) );
        dispatch( fetchObservationsStats( ) );
        dispatch( fetchIdentifiers( ) );
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

function updateAllLocal( changes ) {
  return { type: UPDATE_ALL_LOCAL, changes };
}

function reviewAll( ) {
  return function ( dispatch, getState ) {
    dispatch( updateAllLocal( { reviewedByCurrentUser: true } ) );
    _.forEach( getState( ).observations.results, ( o ) => {
      iNaturalistJS.observations.review( { id: o.id } );
    } );
    dispatch( fetchObservationsStats( ) );
  };
}

function unreviewAll( ) {
  return function ( dispatch, getState ) {
    dispatch( updateAllLocal( { reviewedByCurrentUser: false } ) );
    _.forEach( getState( ).observations.results, ( o ) => {
      iNaturalistJS.observations.unreview( { id: o.id } );
    } );
    dispatch( fetchObservationsStats( ) );
  };
}

export {
  RECEIVE_OBSERVATIONS,
  UPDATE_OBSERVATION_IN_COLLECTION,
  UPDATE_ALL_LOCAL,
  receiveObservations,
  fetchObservations,
  updateObservationInCollection,
  reviewAll,
  unreviewAll,
  updateAllLocal
};

import iNaturalistJS from "inaturalistjs";
import { fetchObservationsStats } from "./observations_stats_actions";
import { fetchIdentifiers } from "./identifiers_actions";
import { setConfig } from "./config_actions";
import { showAlert } from "./alert_actions";
import { paramsForSearch } from "../reducers/search_params_reducer";

const RECEIVE_OBSERVATIONS = "receive_observations";
const UPDATE_OBSERVATION_IN_COLLECTION = "update_observation_in_collection";
const UPDATE_ALL_LOCAL = "update_all_local";

function receiveObservations( results ) {
  return Object.assign( { type: RECEIVE_OBSERVATIONS }, results );
}

function fetchObservations( ) {
  return function ( dispatch, getState ) {
    dispatch( setConfig( { allReviewed: false } ) );
    const s = getState();
    const currentUser = s.config.currentUser ? s.config.currentUser : null;
    const preferredPlace = s.config.preferredPlace ? s.config.preferredPlace : null;
    const apiParams = Object.assign( {
      viewer_id: currentUser.id,
      preferred_place_id: preferredPlace ? preferredPlace.id : null,
      locale: I18n.locale,
      ttl: -1
    }, paramsForSearch( s.searchParams.params ) );
    if ( s.config.blind ) {
      apiParams.order_by = "random";
      apiParams.quality_grade = "any";
      apiParams.page = 1;
    }
    return iNaturalistJS.observations.search( apiParams )
      .then( response => {
        let obs = response.results;
        if ( currentUser.id ) {
          obs = response.results.map( ( o ) => {
            if ( o.reviewed_by.indexOf( currentUser.id ) > -1 ) {
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
    dispatch( setConfig( { allReviewed: true } ) );
    dispatch( updateAllLocal( { reviewedByCurrentUser: true } ) );
    // B/c this was new to me, Promise.all takes an array of Promises and
    // creates another Promise that is fulfilled if all the promises in the
    // array are fulfilled. So here, we only want to fetch the obs stats after
    // all the obs were reviewed. From
    // http://www.html5rocks.com/en/tutorials/es6/promises/. I'm not *really*
    // sure this is a better user experience than the herky-jerkiness of
    // updating the stats after each request, so this might not last, but now
    // I know how to do this
    Promise.all(
      getState( ).observations.results.map( o => iNaturalistJS.observations.review( { id: o.id } ) )
    )
      .catch( ( ) => dispatch( showAlert(
        I18n.t( "failed_to_save_record" ),
        { title: I18n.t( "request_failed" ) }
      ) ) )
      .then( ( ) => dispatch( fetchObservationsStats( ) ) );
  };
}

function unreviewAll( ) {
  return function ( dispatch, getState ) {
    dispatch( setConfig( { allReviewed: false } ) );
    dispatch( updateAllLocal( { reviewedByCurrentUser: false } ) );
    Promise.all(
      getState( ).observations.results.map( o => iNaturalistJS.observations.unreview( { id: o.id } ) )
    )
      .catch( ( ) => dispatch( showAlert(
        I18n.t( "failed_to_save_record" ),
        { title: I18n.t( "request_failed" ) }
      ) ) )
      .then( ( ) => dispatch( fetchObservationsStats( ) ) );
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

import _ from "lodash";
import iNaturalistJS from "inaturalistjs";
import { fetchObservationsStats, resetObservationsStats } from "./observations_stats_actions";
import { setConfig } from "../../../shared/ducks/config";
import { showAlert, hideAlert } from "./alert_actions";
import { paramsForSearch } from "../reducers/search_params_reducer";

const RECEIVE_OBSERVATIONS = "receive_observations";
const UPDATE_OBSERVATION_IN_COLLECTION = "update_observation_in_collection";
const UPDATE_ALL_LOCAL = "update_all_local";
const SET_REVIEWING = "identify/observations/set-reviewing";
const SET_PLACES_BY_ID = "identify/observations/set-places-by-id";
const SET_LAST_REQUEST_AT = "identify/observations/set-last-request-at";

function receiveObservations( results ) {
  return Object.assign( { type: RECEIVE_OBSERVATIONS }, results );
}

function setPlacesByID( placesByID ) {
  return { type: SET_PLACES_BY_ID, placesByID };
}

function setLastRequestAt( lastRequestAt ) {
  return { type: SET_LAST_REQUEST_AT, lastRequestAt };
}

function fetchObservationPlaces( ) {
  return function ( dispatch, getState ) {
    const observations = getState( ).observations.results;
    let placeIDs = _.compact( _.flattenDeep( observations.map(
      o => [o.place_ids, o.private_place_ids]
    ) ) );
    const existingPlaceIDs = _.keys( getState( ).observations.placesByID )
      .map( pid => parseInt( pid, 0 ) );
    placeIDs = _.take(
      _.uniq( _.without( placeIDs, ...existingPlaceIDs ) ),
      100
    );
    if ( placeIDs.length === 0 ) {
      return Promise.resolve( );
    }
    return iNaturalistJS.places.fetch(
      placeIDs, { per_page: 100, no_geom: true }
    ).then( response => {
      dispatch( setPlacesByID( _.keyBy( response.results, "id" ) ) );
    } );
  };
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
    const thisRequestSentAt = new Date( );
    dispatch( setLastRequestAt( thisRequestSentAt ) );
    return iNaturalistJS.observations.search( apiParams )
      .then( response => {
        const { lastRequestAt } = getState( ).observations;
        if ( lastRequestAt && lastRequestAt > thisRequestSentAt ) {
          return;
        }
        let obs = response.results;
        if ( currentUser.id ) {
          obs = response.results.map( o => {
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
        if ( s.config.sideBarHidden ) {
          dispatch( resetObservationsStats( ) );
        } else {
          dispatch( fetchObservationsStats( true ) );
        }
        dispatch( fetchObservationPlaces( ) );
        if ( _.isEmpty( _.filter( obs, o => !o.reviewedByCurrentUser ) ) ) {
          dispatch( setConfig( { allReviewed: true } ) );
        }
      } ).catch( e => {
        const { lastRequestAt } = getState( ).observations;
        if ( lastRequestAt && lastRequestAt > thisRequestSentAt ) {
          return;
        }
        if ( !e.response ) {
          dispatch(
            showAlert(
              "",
              {
                title: I18n.t( "unknown_error" ),
                onClose: dispatch( hideAlert( ) )
              }
            )
          );
          return;
        }
        e.response.json( ).then( json => {
          if ( json.error.match( /window is too large/ ) ) {
            dispatch(
              showAlert(
                I18n.t( "views.observations.identify.too_many_results_desc" ),
                {
                  title: I18n.t( "too_many_results" ),
                  onClose: dispatch( hideAlert( ) )
                }
              )
            );
          }
        } );
        // alert( msg );
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

function setReviewing( reviewing ) {
  return { type: SET_REVIEWING, reviewing };
}

function setReviewed( results, apiMethod ) {
  return dispatch => {
    const lastResult = results.pop( );
    // B/c this was new to me, Promise.all takes an array of Promises and
    // creates another Promise that is fulfilled if all the promises in the
    // array are fulfilled. So here, we only want to fetch the obs stats after
    // all the obs were reviewed. From
    // http://www.html5rocks.com/en/tutorials/es6/promises/. I'm not *really*
    // sure this is a better user experience than the herky-jerkiness of
    // updating the stats after each request, so this might not last, but now
    // I know how to do this
    Promise.all(
      results.map( o => apiMethod( { id: o.id } ) )
    )
      .then( ( ) => {
        if ( lastResult ) {
          return apiMethod( { id: lastResult.id, wait_for_refresh: true } );
        }
        return null;
      } )
      .catch( ( ) => {
        dispatch( setReviewing( false ) );
        dispatch( showAlert(
          I18n.t( "failed_to_save_record" ),
          { title: I18n.t( "request_failed" ) }
        ) );
      } )
      .then( ( ) => {
        dispatch( setReviewing( false ) );
      } );
  };
}

function reviewAll( ) {
  return function ( dispatch, getState ) {
    dispatch( setConfig( { allReviewed: true } ) );
    dispatch( setReviewing( true ) );
    const unreviewedResults = _.filter( getState( ).observations.results,
      o => !o.reviewedByCurrentUser );
    dispatch( updateAllLocal( { reviewedByCurrentUser: true } ) );
    dispatch( setReviewed( unreviewedResults, iNaturalistJS.observations.review ) );
  };
}

function unreviewAll( ) {
  return function ( dispatch, getState ) {
    dispatch( setConfig( { allReviewed: false } ) );
    dispatch( setReviewing( true ) );
    const reviewedResults = _.filter( getState( ).observations.results,
      o => o.reviewedByCurrentUser );
    dispatch( updateAllLocal( { reviewedByCurrentUser: false } ) );
    dispatch( setReviewed( reviewedResults, iNaturalistJS.observations.unreview ) );
  };
}

export {
  RECEIVE_OBSERVATIONS,
  UPDATE_OBSERVATION_IN_COLLECTION,
  UPDATE_ALL_LOCAL,
  SET_REVIEWING,
  SET_PLACES_BY_ID,
  SET_LAST_REQUEST_AT,
  receiveObservations,
  fetchObservations,
  updateObservationInCollection,
  reviewAll,
  unreviewAll,
  updateAllLocal,
  setReviewing,
  setLastRequestAt
};

import _ from "lodash";
import iNaturalistJS from "inaturalistjs";
import { fetchObservationsStats, resetObservationsStats } from "./observations_stats_actions";
import { setConfig } from "../../../shared/ducks/config";
import { showAlert, hideAlert } from "../../../shared/ducks/alert_modal";
import { paramsForSearch } from "../reducers/search_params_reducer";

const RECEIVE_OBSERVATIONS = "receive_observations";
const UPDATE_OBSERVATION_IN_COLLECTION = "update_observation_in_collection";
const UPDATE_ALL_LOCAL = "update_all_local";
const SET_REVIEWING = "identify/observations/set-reviewing";
const SET_PLACES_BY_ID = "identify/observations/set-places-by-id";
const SET_LAST_REQUEST_AT = "identify/observations/set-last-request-at";

const OBSERVATION_FIELDS = {
  id: true,
  comments_count: true,
  identifications_count: true,
  place_ids: true,
  private_place_ids: true,
  observation_photos: {
    id: true
  },
  photos: {
    id: true,
    uuid: true,
    url: true
  },
  reviewed_by: true,
  identifications: {
    current: true,
    user: {
      id: true
    },
    taxon: {
      id: true
    }
  },
  taxon: {
    id: true,
    uuid: true,
    name: true,
    iconic_taxon_name: true,
    is_active: true,
    preferred_common_name: true,
    rank: true,
    rank_level: true,
    default_photo: {
      attribution: true,
      license_code: true,
      url: true,
      square_url: true
    }
  },
  user: {
    id: true,
    login: true,
    name: true,
    icon_url: true
  }
};

function receiveObservations( results ) {
  return { type: RECEIVE_OBSERVATIONS, ...results };
}

function setPlacesByID( placesByID ) {
  return { type: SET_PLACES_BY_ID, placesByID };
}

function setLastRequestAt( lastRequestAt ) {
  return { type: SET_LAST_REQUEST_AT, lastRequestAt };
}

function fetchObservationPlaces( ) {
  return function ( dispatch, getState ) {
    const state = getState( );
    const observations = getState( ).observations.results;
    let placeIDs = _.compact( _.flattenDeep( observations.map(
      o => [o.place_ids, o.private_place_ids]
    ) ) );
    const existingPlaceIDs = _.keys( getState( ).observations.placesByID )
      .map( pid => parseInt( pid, 10 ) );
    placeIDs = _.take(
      _.uniq( _.without( placeIDs, ...existingPlaceIDs ) ),
      100
    );
    if ( placeIDs.length === 0 ) {
      return Promise.resolve( );
    }
    const params = { per_page: 100, no_geom: true };
    if ( state.config.testingApiV2 ) {
      params.fields = {
        id: true,
        name: true,
        display_name: true,
        admin_level: true,
        bbox_area: true
      };
    }
    return iNaturalistJS.places.fetch( placeIDs, params )
      .then( response => {
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
    const apiParams = {
      viewer_id: currentUser.id,
      preferred_place_id: preferredPlace ? preferredPlace.id : null,
      locale: I18n.locale,
      ttl: -1,
      ...paramsForSearch( s.searchParams.params )
    };
    if ( s.config.blind ) {
      apiParams.order_by = "random";
      delete apiParams.quality_grade;
      apiParams.page = 1;
    }
    if ( s.config.testingApiV2 ) {
      apiParams.fields = OBSERVATION_FIELDS;
    }
    _.each( apiParams, ( v, k ) => {
      if ( ( _.isNull( v ) || v === "" || v === "any" ) && !_.startsWith( k, "field:" ) ) {
        delete apiParams[k];
      } else if ( /license$/.test( k ) ) {
        apiParams[k] = _.toLower( v );
      }
    } );
    delete apiParams.createdDateType;
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
            o.identifications_count = _.size( _.filter( o.identifications, "current" ) );
            o.identifications_count = _.size(
              _.filter( o.identifications, i => ( i.current && !i.hidden ) )
            );
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
  return function ( dispatch, getState ) {
    const state = getState( );
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
      results.map( o => apiMethod( { id: state.config.testingApiV2 ? o.uuid : o.id } ) )
    )
      .then( ( ) => {
        if ( lastResult ) {
          return apiMethod( {
            id: state.config.testingApiV2 ? lastResult.uuid : lastResult.id,
            wait_for_refresh: true
          } );
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
    const unreviewedResults = _.filter(
      getState( ).observations.results,
      o => !o.reviewedByCurrentUser
    );
    dispatch( updateAllLocal( { reviewedByCurrentUser: true } ) );
    dispatch( setReviewed( unreviewedResults, iNaturalistJS.observations.review ) );
  };
}

function unreviewAll( ) {
  return function ( dispatch, getState ) {
    dispatch( setConfig( { allReviewed: false } ) );
    dispatch( setReviewing( true ) );
    const reviewedResults = _.filter(
      getState( ).observations.results,
      o => o.reviewedByCurrentUser
    );
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

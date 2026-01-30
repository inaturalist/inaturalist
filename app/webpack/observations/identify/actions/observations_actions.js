import _ from "lodash";
import iNaturalistJS from "inaturalistjs";
import {
  fetchObservationsStats,
  resetObservationsStats,
  prepareParamersForAPIRequest
} from "./observations_stats_actions";
import { setConfig } from "../../../shared/ducks/config";
import { showAlert, hideAlert } from "../../../shared/ducks/alert_modal";
import { paramsForSearch } from "../reducers/search_params_reducer";

import {
  RECEIVE_OBSERVATIONS,
  UPDATE_OBSERVATION_IN_COLLECTION,
  UPDATE_ALL_LOCAL,
  SET_OBSERVATIONS,
  SET_REVIEWING,
  SET_PLACES_BY_ID,
  SET_LAST_REQUEST_AT
} from "./observations_actions_names";

const USER_FIELDS = {
  id: true,
  login: true,
  icon_url: true
};
const MODERATOR_ACTION_FIELDS = {
  action: true,
  id: true,
  created_at: true,
  reason: true,
  user: USER_FIELDS
};
const TAXON_FIELDS = {
  ancestry: true,
  ancestor_ids: true,
  ancestors: {
    id: true,
    uuid: true,
    name: true,
    iconic_taxon_name: true,
    is_active: true,
    preferred_common_name: true,
    rank: true,
    rank_level: true
  },
  default_photo: {
    attribution: true,
    license_code: true,
    url: true,
    square_url: true
  },
  iconic_taxon_name: true,
  id: true,
  is_active: true,
  name: true,
  preferred_common_name: true,
  rank: true,
  rank_level: true
};
const CONTROLLED_TERM_FIELDS = {
  id: true,
  label: true,
  multivalued: true
};
const PROJECT_FIELDS = {
  admins: {
    user_id: true
  },
  icon: true,
  project_observation_fields: {
    id: true,
    observation_field: {
      allowed_values: true,
      datatype: true,
      description: true,
      id: true,
      name: true
    }
  },
  slug: true,
  title: true
};
const OBSERVATION_FIELDS = {
  annotations: {
    controlled_attribute: CONTROLLED_TERM_FIELDS,
    controlled_value: CONTROLLED_TERM_FIELDS,
    user: USER_FIELDS,
    vote_score: true,
    votes: {
      vote_flag: true,
      user: USER_FIELDS
    }
  },
  application: {
    id: true,
    icon: true,
    name: true,
    url: true
  },
  comments: {
    body: true,
    created_at: true,
    flags: { id: true },
    hidden: true,
    id: true,
    moderator_actions: MODERATOR_ACTION_FIELDS,
    spam: true,
    user: USER_FIELDS
  },
  comments_count: true,
  community_taxon: TAXON_FIELDS,
  created_at: true,
  description: true,
  faves: {
    user: USER_FIELDS
  },
  flags: {
    id: true,
    flag: true,
    resolved: true
  },
  geojson: true,
  geoprivacy: true,
  id: true,
  identifications: {
    body: true,
    category: true,
    created_at: true,
    current: true,
    disagreement: true,
    flags: { id: true },
    hidden: true,
    moderator_actions: MODERATOR_ACTION_FIELDS,
    previous_observation_taxon: TAXON_FIELDS,
    spam: true,
    taxon: TAXON_FIELDS,
    taxon_change: { id: true, type: true },
    updated_at: true,
    user: USER_FIELDS,
    uuid: true,
    vision: true
  },
  identifications_most_agree: true,
  // TODO refactor to rely on geojson instead of lat and lon
  latitude: true,
  license_code: true,
  location: true,
  longitude: true,
  map_scale: true,
  non_traditional_projects: {
    current_user_is_member: true,
    project_user: {
      user: USER_FIELDS
    },
    project: PROJECT_FIELDS
  },
  obscured: true,
  observed_on: true,
  observed_time_zone: true,
  ofvs: {
    observation_field: {
      allowed_values: true,
      datatype: true,
      description: true,
      name: true,
      taxon: {
        name: true
      },
      uuid: true
    },
    user: USER_FIELDS,
    uuid: true,
    value: true,
    taxon: TAXON_FIELDS
  },
  outlinks: {
    source: true,
    url: true
  },
  observation_photos: {
    id: true
  },
  photos: {
    id: true,
    uuid: true,
    url: true,
    license_code: true,
    original_dimensions: {
      width: true,
      height: true
    }
  },
  place_guess: true,
  place_ids: true,
  positional_accuracy: true,
  preferences: {
    prefers_community_taxon: true
  },
  private_geojson: true,
  private_place_guess: true,
  private_place_ids: true,
  project_observations: {
    current_user_is_member: true,
    preferences: {
      allows_curator_coordinate_access: true
    },
    project: PROJECT_FIELDS,
    uuid: true
  },
  public_positional_accuracy: true,
  quality_grade: true,
  quality_metrics: {
    id: true,
    metric: true,
    agree: true,
    user: USER_FIELDS
  },
  reviewed_by: true,
  sounds: {
    file_url: true,
    file_content_type: true,
    id: true,
    license_code: true,
    play_local: true,
    url: true,
    uuid: true
  },
  tags: true,
  taxon: TAXON_FIELDS,
  taxon_geoprivacy: true,
  time_observed_at: true,
  time_zone: true,
  user: {
    ...USER_FIELDS,
    name: true,
    observations_count: true,
    preferences: {
      prefers_community_taxa: true,
      prefers_observation_fields_by: true,
      prefers_project_addition_by: true
    }
  },
  viewer_trusted_by_observer: true,
  votes: {
    id: true,
    user: USER_FIELDS,
    vote_flag: true,
    vote_scope: true
  }
};

function receiveObservations( results ) {
  return { type: RECEIVE_OBSERVATIONS, ...results };
}

function setObservations( observations ) {
  return { type: SET_OBSERVATIONS, observations };
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
        const placesByID = _.keyBy( response.results, "id" );
        dispatch( setPlacesByID( placesByID ) );
        // now that we have places, inject the place objects into the observations results
        const observationsWithPlacesAdded = getState( ).observations.results;
        _.each( observationsWithPlacesAdded, observation => {
          if ( observation.places ) {
            return;
          }
          const observationPlaceIDs = _.uniq( _.flatten( [
            observation.place_ids,
            observation.private_place_ids
          ] ) );
          const cachedPlaces = _.compact( observationPlaceIDs.map( pid => placesByID[pid] ) );
          if ( cachedPlaces && cachedPlaces.length > 0 ) {
            observation.places = cachedPlaces;
          }
        } );
        dispatch( setObservations( observationsWithPlacesAdded ) );
      } );
  };
}

function fetchObservations( ) {
  return function ( dispatch, getState ) {
    dispatch( setConfig( { allReviewed: false } ) );
    const s = getState();
    const currentUser = s.config.currentUser ? s.config.currentUser : null;
    if ( !currentUser?.privilegedWith( "interaction" ) ) {
      return null;
    }

    const preferredPlace = s.config.preferredPlace ? s.config.preferredPlace : null;
    let apiParams = {
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
    apiParams = prepareParamersForAPIRequest( apiParams );
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
    const state = getState( );
    dispatch( setConfig( { allReviewed: true } ) );
    dispatch( setReviewing( true ) );
    const unreviewedResults = _.filter(
      state.observations.results,
      o => !o.reviewedByCurrentUser && state.config.currentUserCanInteractWithResource( o )
    );
    dispatch( updateAllLocal( { reviewedByCurrentUser: true } ) );
    dispatch( setReviewed( unreviewedResults, iNaturalistJS.observations.review ) );
  };
}

function unreviewAll( ) {
  return function ( dispatch, getState ) {
    const state = getState( );
    dispatch( setConfig( { allReviewed: false } ) );
    dispatch( setReviewing( true ) );
    const reviewedResults = _.filter(
      state.observations.results,
      o => o.reviewedByCurrentUser && state.config.currentUserCanInteractWithResource( o )
    );
    dispatch( updateAllLocal( { reviewedByCurrentUser: false } ) );
    dispatch( setReviewed( reviewedResults, iNaturalistJS.observations.unreview ) );
  };
}

export {
  OBSERVATION_FIELDS,
  RECEIVE_OBSERVATIONS,
  UPDATE_OBSERVATION_IN_COLLECTION,
  UPDATE_ALL_LOCAL,
  SET_OBSERVATIONS,
  SET_REVIEWING,
  SET_PLACES_BY_ID,
  SET_LAST_REQUEST_AT,
  receiveObservations,
  fetchObservations,
  updateObservationInCollection,
  reviewAll,
  unreviewAll,
  updateAllLocal,
  setObservations,
  setReviewing,
  setLastRequestAt
};

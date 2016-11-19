import inatjs from "inaturalistjs";
import _ from "lodash";
import { defaultObservationParams } from "../../shared/util";
import { setConfig } from "../../../shared/ducks/config";

const SET_OBSERVATION_PHOTOS = "taxa-photos/photos/SET_OBSERVATION_PHOTOS";
const APPEND_OBSERVATION_PHOTOS = "taxa-photos/photos/APPEND_OBSERVATION_PHOTOS";
const UPDATE_OBSERVATION_PARAMS = "taxa-photos/photos/UPDATE_OBSERVATION_PARAMS";
const SET_PHOTOS_GROUP = "taxa-photos/photos/SET_PHOTOS_GROUP";
const CLEAR_GROUPED_PHOTOS = "taxa-photos/photos/CLEAR_GROUPED_PHOTOS";

export default function reducer( state = {
  observationPhotos: [],
  observationParams: {
    order_by: "votes"
  }
}, action ) {
  const newState = Object.assign( { }, state );
  switch ( action.type ) {
    case SET_OBSERVATION_PHOTOS:
      newState.observationPhotos = action.observationPhotos;
      newState.totalResults = action.totalResults;
      newState.page = action.page;
      newState.perPage = action.perPage;
      break;
    case APPEND_OBSERVATION_PHOTOS:
      newState.observationPhotos = newState.observationPhotos.concat( action.observationPhotos );
      newState.totalResults = action.totalResults;
      newState.page = action.page;
      newState.perPage = action.perPage;
      break;
    case UPDATE_OBSERVATION_PARAMS:
      newState.observationParams = Object.assign( { }, state.observationParams,
        action.params );
      _.forEach( newState.observationParams, ( v, k ) => {
        if (
          v === null ||
          v === undefined ||
          ( typeof( v ) === "string" && v.length === 0 )
        ) {
          delete newState.observationParams[k];
        }
      } );
      break;
    case SET_PHOTOS_GROUP: {
      newState.groupedPhotos = newState.groupedPhotos || {};
      newState.groupedPhotos[action.groupName] = {
        groupName: action.groupName,
        observationPhotos: action.observationPhotos,
        groupObject: action.groupObject
      };
      break;
    }
    case CLEAR_GROUPED_PHOTOS:
      delete newState.groupedPhotos;
      break;
    default:
      // ok
  }
  return newState;
}

export function setObservationPhotos(
  observationPhotos,
  totalResults,
  page,
  perPage
) {
  return {
    type: SET_OBSERVATION_PHOTOS,
    observationPhotos,
    totalResults,
    page,
    perPage
  };
}

export function appendObservationPhotos(
  observationPhotos,
  totalResults,
  page,
  perPage
) {
  return {
    type: APPEND_OBSERVATION_PHOTOS,
    observationPhotos,
    totalResults,
    page,
    perPage
  };
}

export function updateObservationParams( params ) {
  return {
    type: UPDATE_OBSERVATION_PARAMS,
    params
  };
}

export function setPhotosGroup( groupName, observationPhotos, groupObject ) {
  return {
    type: SET_PHOTOS_GROUP,
    groupName,
    observationPhotos,
    groupObject
  };
}

export function clearGroupedPhotos( ) {
  return { type: CLEAR_GROUPED_PHOTOS };
}

function observationPhotosFromObservations( observations ) {
  return _.flatten( observations.map( observation =>
    observation.photos.map( photo => ( { photo, observation } ) )
  ) );
}

export function fetchObservationPhotos( options = {} ) {
  return function ( dispatch, getState ) {
    const s = getState( );
    const params = Object.assign(
      { },
      defaultObservationParams( s ),
      s.photos.observationParams,
      {
        page: options.page,
        per_page: options.perPage
      }
    );
    return inatjs.observations.search( params )
      .then( response => {
        const observationPhotos = observationPhotosFromObservations( response.results );
        let action = appendObservationPhotos;
        if ( options.reload ) {
          action = setObservationPhotos;
        }
        dispatch( action(
          observationPhotos,
          response.total_results,
          response.page,
          response.per_page
        ) );
      } );
  };
}

export function fetchMorePhotos( ) {
  return function ( dispatch, getState ) {
    const s = getState( );
    const page = s.photos.page + 1;
    const perPage = s.photos.perPage;
    dispatch( fetchObservationPhotos( { page, perPage } ) );
  };
}

function fetchPhotosGroupedByParam( param, values ) {
  return function ( dispatch, getState ) {
    const s = getState( );
    _.forEach( values, value => {
      let groupName = value;
      let groupObject;
      if ( typeof( value ) === "object" ) {
        groupName = value.id;
        groupObject = value;
      }
      const params = Object.assign(
        { },
        defaultObservationParams( s ),
        s.photos.observationParams,
        {
          per_page: 12,
          [param]: groupName
        }
      );
      dispatch( setPhotosGroup( groupName, [], groupObject ) );
      inatjs.observations.search( params ).then( response => {
        const observationPhotos = observationPhotosFromObservations( response.results );
        dispatch( setPhotosGroup( groupName, observationPhotos, groupObject ) );
      } );
    } );
  };
}

export function setGrouping( param, values ) {
  return function ( dispatch, getState ) {
    dispatch( clearGroupedPhotos( ) );
    if ( param ) {
      dispatch( setConfig( { grouping: { param, values } } ) );
      if ( param === "taxon_id" ) {
        const taxon = getState( ).taxon.taxon;
        dispatch( fetchPhotosGroupedByParam( "taxon_id", taxon.children ) );
      } else {
        dispatch( fetchPhotosGroupedByParam( param, values ) );
      }
    } else {
      dispatch( setConfig( { grouping: null } ) );
      dispatch( fetchObservationPhotos( { reload: true } ) );
    }
  };
}

export function reloadPhotos( ) {
  return function ( dispatch, getState ) {
    const state = getState( );
    if ( state.config.grouping ) {
      dispatch( setGrouping( state.config.grouping.param, state.config.grouping.values ) );
    } else {
      dispatch( fetchObservationPhotos( { reload: true } ) );
    }
  };
}

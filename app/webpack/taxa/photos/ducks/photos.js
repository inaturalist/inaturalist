import inatjs from "inaturalistjs";
import _ from "lodash";
import { defaultObservationParams } from "../../shared/util";
import { setConfig } from "../../../shared/ducks/config";

const SET_OBSERVATION_PHOTOS = "taxa-photos/photos/SET_OBSERVATION_PHOTOS";
const APPEND_OBSERVATION_PHOTOS = "taxa-photos/photos/APPEND_OBSERVATION_PHOTOS";
const UPDATE_OBSERVATION_PARAMS = "taxa-photos/photos/UPDATE_OBSERVATION_PARAMS";
const SET_PHOTOS_GROUP = "taxa-photos/photos/SET_PHOTOS_GROUP";
const CLEAR_GROUPED_PHOTOS = "taxa-photos/photos/CLEAR_GROUPED_PHOTOS";

const setUrl = ( newParams, defaultParams = {
  layout: "fluid",
  order_by: "votes"
} ) => {
  // don't put defaults in the URL
  const urlState = {};
  _.forEach( newParams, ( v, k ) => {
    if ( !v ) {
      return;
    }
    if ( defaultParams[k] !== undefined && defaultParams[k] === v ) {
      return;
    }
    if ( _.isArray( v ) ) {
      urlState[k] = v.join( "," );
    } else {
      urlState[k] = v;
    }
  } );
  if ( !newParams.place_id ) {
    urlState.place_id = "any";
  }
  const title = `Photos: ${$.param( urlState )}`;
  const newUrl = [
    window.location.origin,
    window.location.pathname,
    _.isEmpty( urlState ) ? "" : "?",
    _.isEmpty( urlState ) ? "" : $.param( urlState )
  ].join( "" );
  history.pushState( urlState, title, newUrl );
};

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

function onePhotoPerObservation( observationPhotos ) {
  const singleObservationPhotos = [];
  const obsPhotoHash = {};
  for ( let i = 0; i < observationPhotos.length; i++ ) {
    const observationPhoto = observationPhotos[i];
    if ( !obsPhotoHash[observationPhoto.observation.id] ) {
      obsPhotoHash[observationPhoto.observation.id] = true;
      singleObservationPhotos.push( observationPhoto );
    }
  }
  return singleObservationPhotos;
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
        per_page: options.perPage || 12
      }
    );
    return inatjs.observations.search( params )
      .then( response => {
        let observationPhotos = observationPhotosFromObservations( response.results );
        // For taxa above species, show one photo per observation
        if ( s.taxon.taxon && s.taxon.taxon.rank_level > 10 ) {
          observationPhotos = onePhotoPerObservation( observationPhotos );
        }
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
    const limit = 12;
    const baseParams = Object.assign(
      { },
      defaultObservationParams( s ),
      s.photos.observationParams,
      { per_page: limit }
    );
    _.forEach( values, value => {
      let groupName = value;
      let groupObject;
      const params = Object.assign( { }, baseParams );
      if ( param === "taxon_id" ) {
        groupName = value.id;
        groupObject = value;
        params[param] = groupName;
      } else {
        groupName = value.controlled_value.label;
        params.term_id = value.controlled_attribute.id;
        params.term_value_id = value.controlled_value.id;
      }
      dispatch( setPhotosGroup( groupName, [], groupObject ) );
      inatjs.observations.search( params ).then( response => {
        let observationPhotos = observationPhotosFromObservations( response.results );
        if ( observationPhotos.length > limit ) {
          observationPhotos = _.uniqBy( observationPhotos, op => op.observation.id );
        }
        dispatch( setPhotosGroup( groupName, observationPhotos, groupObject ) );
      } );
    } );
  };
}

function setUrlFromState( state ) {
  const urlState = Object.assign( { }, state.photos.observationParams, {
    grouping: state.config.grouping ? state.config.grouping.param : null,
    layout: state.config.layout ? state.config.layout : "fluid",
    place_id: state.config.chosenPlace ? state.config.chosenPlace.id : null
  } );
  setUrl( urlState );
}

export function updateObservationParamsAndUrl( params ) {
  return function ( dispatch, getState ) {
    dispatch( updateObservationParams( params ) );
    setUrlFromState( getState( ) );
  };
}

export function setConfigAndUrl( params ) {
  return function ( dispatch, getState ) {
    dispatch( setConfig( params ) );
    setUrlFromState( getState( ) );
  };
}

export function setGrouping( param, values ) {
  return function ( dispatch, getState ) {
    dispatch( clearGroupedPhotos( ) );
    if ( param ) {
      if ( param === "taxon_id" ) {
        const taxon = getState( ).taxon.taxon;
        dispatch( setConfigAndUrl( { grouping: { param, values } } ) );
        dispatch( fetchPhotosGroupedByParam( "taxon_id", taxon.children ) );
      } else {
        const fieldValues = getState( ).taxon.fieldValues;
        if ( fieldValues && fieldValues[values] ) {
          // when grouping by a term, remove existing term filters
          dispatch( updateObservationParamsAndUrl( { term_id: null, term_value_id: null } ) );
          dispatch( setConfigAndUrl( { grouping: { param, values } } ) );
          dispatch( fetchPhotosGroupedByParam( param, fieldValues[values] ) );
        } else {
          dispatch( setConfigAndUrl( { grouping: { } } ) );
          dispatch( fetchObservationPhotos( { reload: true } ) );
        }
      }
    } else {
      dispatch( setConfigAndUrl( { grouping: { } } ) );
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

export function hydrateFromUrlParams( params ) {
  return function ( dispatch ) {
    if ( params.grouping ) {
      const match = params.grouping.match( /terms:([0-9]+)$/ );
      if ( match ) {
        dispatch( setGrouping( params.grouping, Number( match[1] ) ) );
      } else {
        dispatch( setGrouping( params.grouping ) );
      }
    }
    if ( params.layout ) {
      dispatch( setConfig( { layout: params.layout } ) );
    }
    if ( params.place_id ) {
      if ( params.place_id === "any" ) {
        dispatch( setConfig( { chosenPlace: null } ) );
      } else {
        inatjs.places.fetch( params.place_id ).then(
          response => {
            dispatch( setConfig( { chosenPlace: response.results[0] } ) );
          },
          error => {
            console.log( "[DEBUG] error: ", error );
          }
        );
      }
    }
    const newObservationParams = { };
    if ( params.order_by ) {
      newObservationParams.order_by = params.order_by;
    }
    _.forEach( params, ( value, key ) => {
      if ( !key.match( /^term(_value)?_id$/ ) ) {
        return;
      }
      newObservationParams[key] = value;
    } );
    if ( !_.isEmpty( newObservationParams ) ) {
      dispatch( updateObservationParams( newObservationParams ) );
    }
  };
}

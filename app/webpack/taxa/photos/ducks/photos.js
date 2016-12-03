import inatjs from "inaturalistjs";
import _ from "lodash";
import { defaultObservationParams } from "../../shared/util";
import { setConfig } from "../../../shared/ducks/config";

if ( window.location.protocol.match( /https/ ) ) {
  inatjs.setConfig( {
    apiHostSSL: true,
    writeHostSSL: true
  } );
}

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
    const limit = 12;
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
          per_page: limit,
          [param]: groupName
        }
      );
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
      dispatch( setConfigAndUrl( { grouping: { param, values } } ) );
      if ( param === "taxon_id" ) {
        const taxon = getState( ).taxon.taxon;
        dispatch( fetchPhotosGroupedByParam( "taxon_id", taxon.children ) );
      } else {
        dispatch( fetchPhotosGroupedByParam( param, values ) );
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
      dispatch( setGrouping( params.grouping ) );
    }
    if ( params.order_by ) {
      dispatch( updateObservationParams( { order_by: params.order_by } ) );
    }
    if ( params.layout ) {
      dispatch( setConfig( { layout: params.layout } ) );
    }
    if ( params.place_id ) {
      if ( params.place_id === "any" ) {
        dispatch( setConfig( { chosenPlace: null } ) );
        dispatch( reloadPhotos( ) );
      } else {
        inatjs.places.fetch( params.place_id ).then(
          response => {
            dispatch( setConfig( { chosenPlace: response.results[0] } ) );
            dispatch( reloadPhotos( ) );
          },
          error => {
            console.log( "[DEBUG] error: ", error );
          }
        );
      }
    }
  };
}

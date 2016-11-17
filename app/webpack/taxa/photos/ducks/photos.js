import inatjs from "inaturalistjs";
import _ from "lodash";
import { defaultObservationParams } from "../../shared/util";

const SET_OBSERVATION_PHOTOS = "taxa-photos/photos/SET_OBSERVATION_PHOTOS";
const APPEND_OBSERVATION_PHOTOS = "taxa-photos/photos/APPEND_OBSERVATION_PHOTOS";

export default function reducer( state = { observationPhotos: [] }, action ) {
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

export function fetchObservationPhotos( page, perPage ) {
  return function ( dispatch, getState ) {
    const params = Object.assign( { }, defaultObservationParams( getState( ) ), {
      page,
      perPage
    } );
    return inatjs.observations.search( params )
      .then( response => {
        const observationPhotos = _.flatten( response.results.map( observation =>
          observation.photos.map( photo => ( { photo, observation } ) )
        ) );
        dispatch( appendObservationPhotos(
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
    dispatch( fetchObservationPhotos( page, perPage ) );
  };
}

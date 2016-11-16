import inatjs from "inaturalistjs";
import _ from "lodash";
import { defaultObservationParams } from "../../shared/util";

const SET_OBSERVATION_PHOTOS = "taxa-photos/photos/SET_OBSERVATION_PHOTOS";

export default function reducer( state = { counts: {} }, action ) {
  const newState = Object.assign( { }, state );
  switch ( action.type ) {
    case SET_OBSERVATION_PHOTOS:
      newState.observationPhotos = action.observationPhotos;
      break;
    default:
      // ok
  }
  return newState;
}

export function setObservationPhotos( observationPhotos ) {
  return {
    type: SET_OBSERVATION_PHOTOS,
    observationPhotos
  };
}

export function fetchObservationPhotos( ) {
  return function ( dispatch, getState ) {
    return inatjs.observations.search( defaultObservationParams( getState( ) ) )
      .then( response => {
        const observationPhotos = _.flatten( response.results.map( observation =>
          observation.photos.map( photo => ( { photo, observation } ) )
        ) );
        dispatch( setObservationPhotos( observationPhotos ) );
      } );
  };
}

import _ from "lodash";

const SET_PHOTO_MODAL = "taxa-show/photo_modal/SET_PHOTO_MODAL";
const SHOW_PHOTO_MODAL = "taxa-show/photo_modal/SHOW_PHOTO_MODAL";
const HIDE_PHOTO_MODAL = "taxa-show/photo_modal/HIDE_PHOTO_MODAL";

export default function reducer( state = { visible: false }, action ) {
  const newState = Object.assign( { }, state );
  switch ( action.type ) {
    case SET_PHOTO_MODAL:
      newState.photo = action.photo;
      newState.taxon = action.taxon;
      newState.observation = action.observation;
      break;
    case SHOW_PHOTO_MODAL:
      newState.visible = true;
      break;
    case HIDE_PHOTO_MODAL:
      newState.visible = false;
      break;
    default:
      // ok
  }
  return newState;
}

export function setPhotoModal( photo, taxon, observation ) {
  return {
    type: SET_PHOTO_MODAL,
    photo,
    taxon,
    observation
  };
}

export function showPhotoModal( ) {
  return { type: SHOW_PHOTO_MODAL };
}

export function hidePhotoModal( ) {
  return { type: HIDE_PHOTO_MODAL };
}

//
// showNext and showPrev both receive a function that takes the state as an
// argument and returns "photo container" objects that each have a photo
// attribute and optional taxon and observation attributes
//
export function showNext( getPhotos ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const photoContainers = getPhotos( s );
    const currentPhoto = s.photoModal.photo;
    const currentIndex = _.findIndex( photoContainers, pc => pc.photo.id === currentPhoto.id );
    if ( currentIndex < 0 ) {
      return;
    }
    let newPhotoContainer = photoContainers[0];
    if ( currentIndex < photoContainers.length - 1 ) {
      newPhotoContainer = photoContainers[currentIndex + 1];
    }
    dispatch( setPhotoModal( newPhotoContainer.photo, newPhotoContainer.taxon ) );
  };
}

export function showPrev( getPhotos ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const photoContainers = getPhotos( s );
    const currentPhoto = s.photoModal.photo;
    const currentIndex = _.findIndex( photoContainers, pc => pc.photo.id === currentPhoto.id );
    if ( currentIndex < 0 ) {
      return;
    }
    let newPhotoContainer = photoContainers[photoContainers.length - 1];
    if ( currentIndex > 0 ) {
      newPhotoContainer = photoContainers[currentIndex - 1];
    }
    dispatch( setPhotoModal( newPhotoContainer.photo, newPhotoContainer.taxon ) );
  };
}

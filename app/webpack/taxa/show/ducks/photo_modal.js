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

export function setPhotoModal( photo, taxon ) {
  return {
    type: SET_PHOTO_MODAL,
    photo,
    taxon
  };
}

export function showPhotoModal( ) {
  return { type: SHOW_PHOTO_MODAL };
}

export function hidePhotoModal( ) {
  return { type: HIDE_PHOTO_MODAL };
}

export function showNext( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const taxonPhotos = s.taxon.taxonPhotos;
    const currentPhoto = s.photoModal.photo;
    const currentIndex = _.findIndex( taxonPhotos, tp => tp.photo.id === currentPhoto.id );
    if ( currentIndex < 0 ) {
      return;
    }
    let newTaxonPhoto = taxonPhotos[0];
    if ( currentIndex < taxonPhotos.length - 1 ) {
      newTaxonPhoto = taxonPhotos[currentIndex + 1];
    }
    dispatch( setPhotoModal( newTaxonPhoto.photo, newTaxonPhoto.taxon ) );
  };
}

export function showPrev( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const taxonPhotos = s.taxon.taxonPhotos;
    const currentPhoto = s.photoModal.photo;
    const currentIndex = _.findIndex( taxonPhotos, tp => tp.photo.id === currentPhoto.id );
    if ( currentIndex < 0 ) {
      return;
    }
    let newTaxonPhoto = taxonPhotos[taxonPhotos.length - 1];
    if ( currentIndex > 0 ) {
      newTaxonPhoto = taxonPhotos[currentIndex - 1];
    }
    dispatch( setPhotoModal( newTaxonPhoto.photo, newTaxonPhoto.taxon ) );
  };
}

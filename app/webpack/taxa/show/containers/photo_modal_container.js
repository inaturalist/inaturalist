import { connect } from "react-redux";
import PhotoModal from "../../shared/components/photo_modal";
import {
  hidePhotoModal,
  showNext as showNextPhoto,
  showPrev as showPrevPhoto
} from "../../shared/ducks/photo_modal";

function mapStateToProps( state ) {
  return {
    photo: state.photoModal.photo,
    taxon: state.photoModal.taxon,
    observation: state.photoModal.observation,
    visible: state.photoModal.visible
  };
}

function mapDispatchToProps( dispatch ) {
  const getPhotos = state => state.taxon.taxonPhotos;
  return {
    showNext: ( ) => {
      dispatch( showNextPhoto( getPhotos ) );
    },
    showPrev: ( ) => {
      dispatch( showPrevPhoto( getPhotos ) );
    },
    onClose: ( ) => dispatch( hidePhotoModal( ) )
  };
}

const PhotoModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoModal );

export default PhotoModalContainer;

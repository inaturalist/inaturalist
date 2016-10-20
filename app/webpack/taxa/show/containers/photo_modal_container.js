import { connect } from "react-redux";
import PhotoModal from "../components/photo_modal";
import { hidePhotoModal } from "../ducks/photo_modal";

function mapStateToProps( state ) {
  return {
    photo: state.photoModal.photo,
    taxon: state.photoModal.taxon,
    visible: state.photoModal.visible
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNext: ( ) => {
      // TODO
    },
    showPrev: ( ) => {
      // TODO
    },
    onClose: ( ) => dispatch( hidePhotoModal( ) )
  };
}

const PhotoModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoModal );

export default PhotoModalContainer;

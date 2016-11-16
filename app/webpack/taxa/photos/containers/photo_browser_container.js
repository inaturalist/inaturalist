import { connect } from "react-redux";
import PhotoBrowser from "../components/photo_browser";
import { showPhotoModal, setPhotoModal } from "../../shared/ducks/photo_modal";

function mapStateToProps( state ) {
  if ( state.photos.observationPhotos && state.photos.observationPhotos.length > 0 ) {
    return {
      observationPhotos: state.photos.observationPhotos
    };
  }
  return {
    observationPhotos: []
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showTaxonPhotoModal: ( photo, taxon, observation ) => {
      dispatch( setPhotoModal( photo, taxon, observation ) );
      dispatch( showPhotoModal( ) );
    }
  };
}

const PhotoBrowserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoBrowser );

export default PhotoBrowserContainer;

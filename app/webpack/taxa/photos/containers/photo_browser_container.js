import { connect } from "react-redux";
import PhotoBrowser from "../components/photo_browser";
import { showPhotoModal, setPhotoModal } from "../../shared/ducks/photo_modal";
import { fetchMorePhotos } from "../ducks/photos";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  if ( state.photos.observationPhotos && state.photos.observationPhotos.length > 0 ) {
    return {
      observationPhotos: state.photos.observationPhotos,
      hasMorePhotos: ( state.photos.totalResults > state.photos.page * state.photos.perPage ),
      layout: state.config.layout
    };
  }
  return {
    observationPhotos: [],
    hasMorePhotos: false,
    layout: state.config.layout
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showTaxonPhotoModal: ( photo, taxon, observation ) => {
      dispatch( setPhotoModal( photo, taxon, observation ) );
      dispatch( showPhotoModal( ) );
    },
    loadMorePhotos: ( ) => {
      dispatch( fetchMorePhotos( ) );
    },
    setLayout: layout => {
      dispatch( setConfig( { layout } ) );
    }
  };
}

const PhotoBrowserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoBrowser );

export default PhotoBrowserContainer;

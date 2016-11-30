import { connect } from "react-redux";
import PhotoPreview from "../components/photo_preview";
import { showPhotoModal, setPhotoModal } from "../../shared/ducks/photo_modal";
import { showPhotoChooser } from "../../shared/ducks/taxon";

function mapStateToProps( state ) {
  if ( !state.taxon.taxonPhotos ) {
    return { taxonPhotos: [] };
  }
  let layout = "gallery";
  const taxonPhotos = state.taxon.taxonPhotos;
  if ( state.taxon.taxon.rank_level > 10 && taxonPhotos.length >= 9 ) {
    layout = "grid";
  }
  return {
    taxon: state.taxon.taxon,
    taxonPhotos,
    layout
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showTaxonPhotoModal: ( photo, taxon, observation ) => {
      dispatch( setPhotoModal( photo, taxon, observation ) );
      dispatch( showPhotoModal( ) );
    },
    showPhotoChooserModal: ( ) => dispatch( showPhotoChooser( ) )
  };
}

const PhotoPreviewContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoPreview );

export default PhotoPreviewContainer;

import { connect } from "react-redux";
import _ from "lodash";
import PhotoPreview from "../components/photo_preview";
import { showPhotoModal, setPhotoModal } from "../ducks/photo_modal";

function mapStateToProps( state ) {
  if ( !state.taxon.taxon || !state.taxon.taxon.taxonPhotos ) {
    return { taxonPhotos: [] };
  }
  let layout = "gallery";
  const taxonPhotos = _.uniqBy( state.taxon.taxon.taxonPhotos, tp => tp.photo.id );
  if ( state.taxon.taxon.rank_level > 10 && taxonPhotos.length >= 9 ) {
    layout = "grid";
  }
  return {
    taxonPhotos,
    layout
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showTaxonPhotoModal: ( taxonPhoto ) => {
      dispatch( setPhotoModal( taxonPhoto.photo, taxonPhoto.taxon ) );
      dispatch( showPhotoModal( ) );
    }
  };
}

const PhotoPreviewContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoPreview );

export default PhotoPreviewContainer;

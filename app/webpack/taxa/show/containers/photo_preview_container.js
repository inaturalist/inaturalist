import { connect } from "react-redux";
import PhotoPreview from "../components/photo_preview";
import { showPhotoModal, setPhotoModal } from "../../shared/ducks/photo_modal";
import { showPhotoChooserIfSignedIn } from "../../shared/ducks/taxon";
import { showNewTaxon } from "../actions/taxon";

function mapStateToProps( state ) {
  if ( !state.taxon.taxonPhotos || state.taxon.taxonPhotos.length === 0 ) {
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
    layout,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showTaxonPhotoModal: ( photo, taxon, observation ) => {
      dispatch( setPhotoModal( photo, taxon, observation ) );
      dispatch( showPhotoModal( ) );
    },
    showPhotoChooserModal: ( ) => dispatch( showPhotoChooserIfSignedIn( ) ),
    showNewTaxon: taxon => dispatch( showNewTaxon( taxon ) )
  };
}

const PhotoPreviewContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoPreview );

export default PhotoPreviewContainer;

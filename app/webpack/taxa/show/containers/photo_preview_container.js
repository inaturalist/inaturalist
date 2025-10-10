import _ from "lodash";
import { connect } from "react-redux";
import PhotoPreview from "../components/photo_preview";
import { showPhotoModal, setPhotoModal } from "../../shared/ducks/photo_modal";
import { showPhotoChooserIfSignedIn } from "../../shared/ducks/taxon";
import { showNewTaxon } from "../actions/taxon";

// if there is a `photo_id` URL parameter, and that photo exists in the
// current taxon's taxonPhotos, rearrange the taxonPhotos so the requested
// photo is the first item in the taxonPhotos array
function rearrangePhotos( taxonPhotos ) {
  const urlParams = new URLSearchParams( window.location.search );
  const initialPhotoID = Number( urlParams.get( "photo_id" ) );
  if ( !initialPhotoID ) {
    return taxonPhotos;
  }

  const initialPhoto = _.find( taxonPhotos, tp => tp?.photo?.id === initialPhotoID );
  if ( !initialPhoto ) {
    return taxonPhotos;
  }
  return [initialPhoto].concat( _.reject(
    taxonPhotos,
    tp => tp?.photo?.id === initialPhotoID
  ) );
}

function mapStateToProps( state ) {
  if ( !state.taxon.taxonPhotos || state.taxon.taxonPhotos.length === 0 ) {
    return {
      taxonPhotos: [],
      config: state.config
    };
  }
  let layout = "gallery";
  let { taxonPhotos } = state.taxon;
  taxonPhotos = rearrangePhotos( taxonPhotos );
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

import { connect } from "react-redux";
import PhotoPreview from "../components/photo_preview";

function mapStateToProps( state ) {
  if ( !state.taxon.taxon || !state.taxon.taxon.taxonPhotos ) {
    return { photos: [] };
  }
  let layout = "gallery";
  if ( state.taxon.taxon.rank_level > 10 && state.taxon.taxon.taxonPhotos.length >= 9 ) {
    layout = "grid";
  }
  return {
    photos: state.taxon.taxon.taxonPhotos.map( tp => tp.photo ),
    layout
  };
}

const PhotoPreviewContainer = connect(
  mapStateToProps
)( PhotoPreview );

export default PhotoPreviewContainer;

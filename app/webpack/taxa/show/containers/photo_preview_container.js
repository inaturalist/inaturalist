import { connect } from "react-redux";
import PhotoPreview from "../components/photo_preview";

function mapStateToProps( state ) {
  if ( !state.taxon.taxon || !state.taxon.taxon.defaultPhotos ) {
    return { photos: [] };
  }
  return {
    photos: state.taxon.taxon.defaultPhotos,
    layout: state.taxon.taxon.rank_level > 10 && state.taxon.taxon.defaultPhotos.length >= 9 ? "grid" : "gallery"
  };
}

function mapDispatchToProps( ) {
  return {};
}

const PhotoPreviewContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoPreview );

export default PhotoPreviewContainer;

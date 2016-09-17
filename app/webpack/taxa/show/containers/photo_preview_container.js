import { connect } from "react-redux";
import PhotoPreview from "../components/photo_preview";

function mapStateToProps( state ) {
  if ( !state.taxon.taxon || !state.taxon.taxon.defaultPhoto ) {
    return { photos: [] };
  }
  return {
    photos: [state.taxon.taxon.defaultPhoto] // state.taxon.taxon.taxon_photos.map( tp => tp.photo )
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

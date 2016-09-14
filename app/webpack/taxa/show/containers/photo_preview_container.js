import { connect } from "react-redux";
import PhotoPreview from "../components/photo_preview";

function mapStateToProps( state ) {
  return {
    photos: state.taxon.taxon.taxon_photos.map( tp => tp.photo )
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

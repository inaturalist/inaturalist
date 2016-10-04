import { connect } from "react-redux";
import _ from "lodash";
import PhotoPreview from "../components/photo_preview";

function mapStateToProps( state ) {
  if ( !state.taxon.taxon || !state.taxon.taxon.taxonPhotos ) {
    return { photos: [] };
  }
  let layout = "gallery";
  const photos = _.uniqBy( state.taxon.taxon.taxonPhotos.map( tp => tp.photo ), p => p.id );
  if ( state.taxon.taxon.rank_level > 10 && photos.length >= 9 ) {
    layout = "grid";
  }
  return {
    photos,
    layout
  };
}

const PhotoPreviewContainer = connect(
  mapStateToProps
)( PhotoPreview );

export default PhotoPreviewContainer;

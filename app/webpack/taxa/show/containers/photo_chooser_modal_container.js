import { connect } from "react-redux";
import PhotoChooserModal from "../components/photo_chooser_modal";
import HTML5Backend from "react-dnd-html5-backend";
import { DragDropContext as dragDropContext } from "react-dnd";
import { updatePhotos, hidePhotoChooser } from "../../shared/ducks/taxon";

function mapStateToProps( state ) {
  const taxon = state.taxon.taxon;
  const chosen = state.taxon.taxonPhotos
    .filter( tp => tp.taxon.id === taxon.id )
    .map( tp => Object.assign( { }, tp.photo, {
      thumb_url: tp.photo.photoUrl( "thumb" )
    } ) );
  return {
    chosen,
    initialQuery: state.taxon.taxon.name,
    visible: state.taxon.photoChooserVisible
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onSubmit: chosen => {
      dispatch( updatePhotos( chosen ) );
    },
    onClose: ( ) => {
      dispatch( hidePhotoChooser( ) );
    }
  };
}

const PhotoChooserModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( dragDropContext( HTML5Backend )( PhotoChooserModal ) );

export default PhotoChooserModalContainer;

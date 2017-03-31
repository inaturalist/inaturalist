import { connect } from "react-redux";
import PhotoChooserModal from "../components/photo_chooser_modal";
import HTML5Backend from "react-dnd-html5-backend";
import TouchBackend from "react-dnd-touch-backend";
import { DragDropContext as dragDropContext } from "react-dnd";
import { updatePhotos, hidePhotoChooser } from "../../shared/ducks/taxon";

// https://gist.github.com/59naga/ed6714519284d36792ba
const isTouchDevice = navigator.userAgent.match(
  /(Android|webOS|iPhone|iPad|iPod|BlackBerry|Windows Phone)/i ) !== null;

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

// Use of TouchBackend is done in the laziest way possible. It *should* have a
// custom drag preview implemented, but I couldn't figure out how to get that
// work properly
const PhotoChooserModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( dragDropContext( isTouchDevice ? TouchBackend : HTML5Backend )( PhotoChooserModal ) );

export default PhotoChooserModalContainer;

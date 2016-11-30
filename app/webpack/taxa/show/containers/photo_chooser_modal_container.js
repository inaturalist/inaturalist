import { connect } from "react-redux";
import PhotoChooserModal from "../components/photo_chooser_modal";
import HTML5Backend from "react-dnd-html5-backend";
import { DragDropContext } from "react-dnd";

function mapStateToProps( state ) {
  return {
    chosen: state.taxon.taxon.photos,
    initialQuery: state.taxon.taxon.name,
    visible: state.taxon.photoChooserVisible
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onSubmit: chosen => {
      console.log( "[DEBUG] chosen: ", chosen );
    }
  };
}

const PhotoChooserModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DragDropContext( HTML5Backend )( PhotoChooserModal ) );

export default PhotoChooserModalContainer;

import { connect } from "react-redux";
import PhotoBrowser from "../components/photo_browser";
import { setMediaViewerState } from "../ducks/media_viewer";
import { onFileDrop } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observation: state.observation
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onFileDrop: ( droppedFiles, e ) => {
      dispatch( onFileDrop( droppedFiles, e ) );
    },
    setMediaViewerState: ( key, value ) => {
      dispatch( setMediaViewerState( key, value ) );
    }
  };
}

const PhotoBrowserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoBrowser );

export default PhotoBrowserContainer;

import { connect } from "react-redux";
import MediaViewer from "../components/media_viewer";
import { setMediaViewerState } from "../ducks/media_viewer";

function mapStateToProps( state ) {
  return {
    mediaViewer: state.mediaViewer,
    observation: state.observation
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setMediaViewerState: ( key, value ) => {
      dispatch( setMediaViewerState( key, value ) );
    }
  };
}

const MediaViewerContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( MediaViewer );

export default MediaViewerContainer;

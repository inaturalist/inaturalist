import { connect } from "react-redux";
import PhotoBrowser from "../components/photo_browser";
import { setMediaViewerState } from "../ducks/media_viewer";
import { onFileDrop } from "../ducks/observation";
import { setFlaggingModalState } from "../ducks/flagging_modal";
import {
  showModeratorActionForm,
  revealHiddenContent
} from "../../../shared/ducks/moderator_actions";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observation: state.observation
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onFileDrop: ( droppedFiles, rejectedFiles, e ) => {
      dispatch( onFileDrop( droppedFiles, rejectedFiles, e ) );
    },
    setMediaViewerState: ( key, value ) => {
      dispatch( setMediaViewerState( key, value ) );
    },
    setFlaggingModalState: state => dispatch( setFlaggingModalState( state ) ),
    hideContent: item => dispatch( showModeratorActionForm( item, "hide" ) ),
    unhideContent: item => dispatch( showModeratorActionForm( item, "unhide" ) ),
    revealHiddenContent: item => dispatch( revealHiddenContent( item ) )
  };
}

const PhotoBrowserContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoBrowser );

export default PhotoBrowserContainer;

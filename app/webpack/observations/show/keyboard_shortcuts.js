import { bind } from "mousetrap";
import { setActiveTab } from "./ducks/comment_id_panel";
import { setMediaViewerState, toggleMediaViewer } from "./ducks/media_viewer";

const bindShortcut = ( shortcut, callback ) => {
  bind( shortcut, ( ) => {
    callback( );
    return false;
  } );
};

const focusCommentIDInput = ( ) => {
  $( ".comment_id_panel .active :input:visible" ).first( ).focus( );
};

const setupKeyboardShortcuts = dispatch => {
  bindShortcut( "i", ( ) => {
    dispatch( setMediaViewerState( { show: false } ) );
    dispatch( setActiveTab( "add_id" ) );
    setTimeout( focusCommentIDInput, 200 );
  } );
  bindShortcut( "c", ( ) => {
    dispatch( setMediaViewerState( { show: false } ) );
    dispatch( setActiveTab( "comment" ) );
    setTimeout( focusCommentIDInput, 200 );
  } );
  bindShortcut( "p", ( ) => {
    dispatch( toggleMediaViewer( ) );
  } );
};

export default setupKeyboardShortcuts;

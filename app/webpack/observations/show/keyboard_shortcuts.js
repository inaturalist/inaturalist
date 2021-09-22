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
  let input = $( ".comment_id_panel .active input:visible" ).filter( ":text" ).first( );
  input = input.length > 0 ? input : $( ".comment_id_panel .active textarea:visible" ).first( );
  input.focus( );
};

const setupKeyboardShortcuts = dispatch => {
  bindShortcut( "i", ( ) => {
    dispatch( setMediaViewerState( { show: false } ) );
    dispatch( setActiveTab( "add_id" ) );
    setTimeout( focusCommentIDInput, 300 );
  } );
  bindShortcut( "c", ( ) => {
    dispatch( setMediaViewerState( { show: false } ) );
    dispatch( setActiveTab( "comment" ) );
    setTimeout( focusCommentIDInput, 300 );
  } );
  bindShortcut( "z", ( ) => {
    dispatch( toggleMediaViewer( ) );
  } );
};

export default setupKeyboardShortcuts;

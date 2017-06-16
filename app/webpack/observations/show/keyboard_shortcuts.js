import { bind } from "mousetrap";
import { setActiveTab } from "./ducks/comment_id_panel";

const bindShortcut = ( shortcut, callback ) => {
  bind( shortcut, ( ) => {
    callback( );
    return false;
  } );
};

const focus = ( ) => {
  $( ".comment_id_panel .active textarea" ).first( ).focus( );
};

const setupKeyboardShortcuts = dispatch => {
  bindShortcut( "i", ( ) => {
    dispatch( setActiveTab( "add_id" ) );
    setTimeout( focus, 200 );
  } );
  bindShortcut( "c", ( ) => {
    dispatch( setActiveTab( "comment" ) );
    setTimeout( focus, 200 );
  } );
};

export default setupKeyboardShortcuts;

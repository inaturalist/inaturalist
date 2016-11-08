import { bind } from "mousetrap";
import {
  addComment,
  addIdentification,
  agreeWithCurrentObservation,
  showNextObservation,
  showPrevObservation,
  toggleCaptive,
  toggleReviewed
} from "./actions/";

const bindShortcut = ( shortcut, action, dispatch, options = { } ) => {
  bind( shortcut, ( ) => {
    dispatch( action( ) );
    return false;
  }, options.eventType );
};

const setupKeyboardShortcuts = ( dispatch ) => {
  bindShortcut( "right", showNextObservation, dispatch );
  bindShortcut( "left", showPrevObservation, dispatch );
  bindShortcut( "i", addIdentification, dispatch );
  bindShortcut( "c", addComment, dispatch );
  bindShortcut( "z", toggleCaptive, dispatch, { eventType: "keyup" } );
  bindShortcut( "r", toggleReviewed, dispatch, { eventType: "keyup" } );
  bindShortcut( "a", agreeWithCurrentObservation, dispatch, { eventType: "keyup" } );
};

export default setupKeyboardShortcuts;

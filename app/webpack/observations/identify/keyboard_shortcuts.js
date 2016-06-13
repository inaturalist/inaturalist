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

const bindShortcut = ( shortcut, action, dispatch ) => {
  bind( shortcut, ( ) => {
    dispatch( action( ) );
    return false;
  } );
};

const setupKeyboardShortcuts = ( dispatch ) => {
  bindShortcut( "right", showNextObservation, dispatch );
  bindShortcut( "left", showPrevObservation, dispatch );
  bindShortcut( "i", addIdentification, dispatch );
  bindShortcut( "c", addComment, dispatch );
  bindShortcut( "z", toggleCaptive, dispatch );
  bindShortcut( "r", toggleReviewed, dispatch );
  bindShortcut( "a", agreeWithCurrentObservation, dispatch );
};

export default setupKeyboardShortcuts;

import { bind } from "mousetrap";
import {
  addComment,
  addIdentification,
  agreeWithCurrentObservation,
  showNextObservation,
  showPrevObservation,
  toggleCaptive,
  toggleReviewed,
  addAnnotationFromKeyboard,
  zoomCurrentPhoto,
  showPrevPhoto,
  showNextPhoto
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
  bindShortcut( "space", zoomCurrentPhoto, dispatch );
  bindShortcut( "command+left", showPrevPhoto, dispatch );
  bindShortcut( "command+right", showNextPhoto, dispatch );
  // Works for now but it's brittle, and will be confusing for locales other
  // than English. It might be wiser to move this logic to an action or a
  // reducer when the controlled terms get set
  ["Adult", "Teneral", "Pupa", "Nymph", "Larva", "Egg", "Juvenile"].forEach( v => {
    bind( `l ${v[0].toLowerCase( )}`, ( ) => {
      dispatch( addAnnotationFromKeyboard( "Life Stage", v ) );
      return false;
    } );
  } );
  bind( "p l", ( ) => {
    dispatch( addAnnotationFromKeyboard( "Plant Phenology", "Flowering" ) );
    return false;
  } );
  bind( "p r", ( ) => {
    dispatch( addAnnotationFromKeyboard( "Plant Phenology", "Fruiting" ) );
    return false;
  } );
};

export default setupKeyboardShortcuts;

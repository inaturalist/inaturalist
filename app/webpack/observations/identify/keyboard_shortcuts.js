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
  showNextPhoto,
  showPrevTab,
  showNextTab,
  toggleKeyboardShortcuts
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
  bindShortcut( "x", toggleCaptive, dispatch, { eventType: "keyup" } );
  bindShortcut( "r", toggleReviewed, dispatch, { eventType: "keyup" } );
  bindShortcut( "a", agreeWithCurrentObservation, dispatch, { eventType: "keyup" } );
  bindShortcut( "z", zoomCurrentPhoto, dispatch );
  bindShortcut( ["command+left", "alt+left"], showPrevPhoto, dispatch );
  bindShortcut( ["command+right", "alt+right"], showNextPhoto, dispatch );
  bindShortcut( "shift+left", showPrevTab, dispatch );
  bindShortcut( "shift+right", showNextTab, dispatch );
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
  bind( "s f", ( ) => {
    dispatch( addAnnotationFromKeyboard( "Sex", "Female" ) );
    return false;
  } );
  bind( "s m", ( ) => {
    dispatch( addAnnotationFromKeyboard( "Sex", "Male" ) );
    return false;
  } );
  bindShortcut( "?", toggleKeyboardShortcuts, dispatch );
};

export default setupKeyboardShortcuts;

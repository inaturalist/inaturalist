import _ from "lodash";
import { bind } from "mousetrap";
import {
  addComment,
  addIdentification,
  agreeWithCurrentObservation,
  showNextObservation,
  showPrevObservation,
  toggleCaptive,
  toggleReviewed,
  toggleFave,
  togglePlayFirstSound,
  addAnnotationFromKeyboard,
  zoomCurrentPhoto,
  showPrevPhoto,
  showNextPhoto,
  showPrevTab,
  showNextTab,
  toggleKeyboardShortcuts,
  addProjects,
  addObservationFields
} from "./actions";
import { increaseBrightness, decreaseBrightness } from "./ducks/brightnesses";

const bindShortcut = ( shortcut, action, dispatch, options = { } ) => {
  bind( shortcut, ( ) => {
    dispatch( action( ) );
    if ( options.callback ) { options.callback( ); }
    return false;
  }, options.eventType );
};

// Works for now but it's brittle, and will be confusing for locales other
// than English. It might be wiser to move this logic to an action or a
// reducer when the controlled terms get set
const annotationShortcuts = [
  // Life Stage
  {
    shortcut: "l a",
    term: "Life Stage",
    value: "Adult"
  },
  {
    shortcut: "l j",
    term: "Life Stage",
    value: "Juvenile"
  },
  {
    shortcut: "l t",
    term: "Life Stage",
    value: "Teneral"
  },
  {
    shortcut: "l p",
    term: "Life Stage",
    value: "Pupa"
  },
  {
    shortcut: "l n",
    term: "Life Stage",
    value: "Nymph"
  },
  {
    shortcut: "l l",
    term: "Life Stage",
    value: "Larva"
  },
  {
    shortcut: "l s",
    term: "Life Stage",
    value: "Subimago"
  },
  {
    shortcut: "l e",
    term: "Life Stage",
    value: "Egg"
  },

  // Flowers and Fruits
  {
    shortcut: "p u",
    term: "Flowers and Fruits",
    value: "Flower Buds"
  },
  {
    shortcut: "p l",
    term: "Flowers and Fruits",
    value: "Flowers"
  },
  {
    shortcut: "p r",
    term: "Flowers and Fruits",
    value: "Fruits or Seeds"
  },
  {
    shortcut: "p n",
    term: "Flowers and Fruits",
    value: "No Flowers or Fruits"
  },

  // Leaves
  {
    shortcut: "v n",
    term: "Leaves",
    value: "No Live Leaves"
  },
  {
    shortcut: "v b",
    term: "Leaves",
    value: "Breaking Leaf Buds"
  },
  {
    shortcut: "v g",
    term: "Leaves",
    value: "Green Leaves"
  },
  {
    shortcut: "v c",
    term: "Leaves",
    value: "Colored Leaves"
  },
  // Sex
  {
    shortcut: "s f",
    term: "Sex",
    value: "Female"
  },
  {
    shortcut: "s m",
    term: "Sex",
    value: "Male"
  },
  {
    shortcut: "s c",
    term: "Sex",
    value: "Cannot Be Determined"
  },

  // Alive or Dead
  {
    shortcut: "a a",
    term: "Alive or Dead",
    value: "Alive"
  },
  {
    shortcut: "a d",
    term: "Alive or Dead",
    value: "Dead"
  },
  {
    shortcut: "a c",
    term: "Alive or Dead",
    value: "Cannot Be Determined"
  },

  // Evidence of Presence
  {
    shortcut: "e o",
    term: "Evidence of Presence",
    value: "Organism"
  },
  {
    shortcut: "e f",
    term: "Evidence of Presence",
    value: "Feather"
  },
  {
    shortcut: "e s",
    term: "Evidence of Presence",
    value: "Scat"
  },
  {
    shortcut: "e t",
    term: "Evidence of Presence",
    value: "Track"
  },
  {
    shortcut: "e b",
    term: "Evidence of Presence",
    value: "Bone"
  },
  {
    shortcut: "e m",
    term: "Evidence of Presence",
    value: "Molt"
  },
  {
    shortcut: "e g",
    term: "Evidence of Presence",
    value: "Gall"
  },
  {
    shortcut: "e e",
    term: "Evidence of Presence",
    value: "Egg"
  },
  {
    shortcut: "e h",
    term: "Evidence of Presence",
    value: "Hair"
  },
  {
    shortcut: "e l",
    term: "Evidence of Presence",
    value: "Leafmine"
  },
  {
    shortcut: "e c",
    term: "Evidence of Presence",
    value: "Construction"
  }
];

const focusCommentIDInput = ( ) => {
  $( ".CommentForm,.IdentificationForm" )
    .not( ".collapse" )
    .find( "textarea,input:visible" )
    .first( )
    .focus( );
};

const focusProjects = ( ) => {
  setTimeout( ( ) => {
    $( ".Projects .panel-collapse" )
      .not( "[aria-expanded=false]" )
      .find( ".ac-chooser input" )
      .first( )
      .focus( );
  }, 200 );
};

const focusObservationFields = ( ) => {
  setTimeout( ( ) => {
    $( ".ObservationFields .panel-collapse" )
      .not( "[aria-expanded=false]" )
      .find( ".ac-chooser input" )
      .first( )
      .focus( );
  }, 200 );
};

const setupKeyboardShortcuts = dispatch => {
  bindShortcut( "right", showNextObservation, dispatch, { eventType: "keyup" } );
  bindShortcut( "left", showPrevObservation, dispatch, { eventType: "keyup" } );
  bindShortcut( "i", addIdentification, dispatch, { callback: focusCommentIDInput } );
  bindShortcut( "c", addComment, dispatch, { callback: focusCommentIDInput } );
  bindShortcut( "x", toggleCaptive, dispatch, { eventType: "keyup" } );
  bindShortcut( "r", toggleReviewed, dispatch, { eventType: "keyup" } );
  bindShortcut( "a", agreeWithCurrentObservation, dispatch, { eventType: "keyup" } );
  bindShortcut( "z", zoomCurrentPhoto, dispatch );
  bindShortcut( "space", togglePlayFirstSound, dispatch, { eventType: "keydown" } );
  bindShortcut( "f", toggleFave, dispatch );
  bindShortcut( ["command+left", "alt+left"], showPrevPhoto, dispatch );
  bindShortcut( ["command+right", "alt+right"], showNextPhoto, dispatch );
  bindShortcut( "shift+left", showPrevTab, dispatch );
  bindShortcut( "shift+right", showNextTab, dispatch );
  bindShortcut( ["command+up", "alt+up"], increaseBrightness, dispatch );
  bindShortcut( ["command+down", "alt+down"], decreaseBrightness, dispatch );
  bindShortcut( "shift+p", addProjects, dispatch, { callback: focusProjects } );
  bindShortcut( "shift+f", addObservationFields, dispatch, { callback: focusObservationFields } );
  _.forEach( annotationShortcuts, as => {
    bind( as.shortcut, ( ) => {
      dispatch( addAnnotationFromKeyboard( as.term, as.value ) );
      return false;
    } );
  } );
  bindShortcut( "?", toggleKeyboardShortcuts, dispatch );
};

export default setupKeyboardShortcuts;
export { annotationShortcuts };

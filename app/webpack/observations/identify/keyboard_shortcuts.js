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

const setupKeyboardShortcuts = ( dispatch, getState ) => {
  const isModalVisible = ( ) => getState( ).currentObservation.visible;

  const bindShortcut = ( shortcut, action, options = { } ) => {
    bind( shortcut, ( ) => {
      if ( options.modalOnly && !isModalVisible( ) ) return false;
      dispatch( action( ) );
      if ( options.callback ) { options.callback( ); }
      return false;
    }, options.eventType );
  };

  // Arrow keys handle their own visibility checks in their actions,
  // so they remain active even when the modal is hidden
  bindShortcut( "right", showNextObservation, { eventType: "keyup" } );
  bindShortcut( "left", showPrevObservation, { eventType: "keyup" } );
  // All other shortcuts only apply when the observation modal is visible
  bindShortcut( "i", addIdentification, { modalOnly: true, callback: focusCommentIDInput } );
  bindShortcut( "c", addComment, { modalOnly: true, callback: focusCommentIDInput } );
  bindShortcut( "x", toggleCaptive, { modalOnly: true, eventType: "keyup" } );
  bindShortcut( "r", toggleReviewed, { modalOnly: true, eventType: "keyup" } );
  bindShortcut( "a", agreeWithCurrentObservation, { modalOnly: true, eventType: "keyup" } );
  bindShortcut( "z", zoomCurrentPhoto, { modalOnly: true } );
  bindShortcut( "space", togglePlayFirstSound, { modalOnly: true, eventType: "keydown" } );
  bindShortcut( "f", toggleFave, { modalOnly: true } );
  bindShortcut( ["command+left", "alt+left"], showPrevPhoto, { modalOnly: true } );
  bindShortcut( ["command+right", "alt+right"], showNextPhoto, { modalOnly: true } );
  bindShortcut( "shift+left", showPrevTab, { modalOnly: true } );
  bindShortcut( "shift+right", showNextTab, { modalOnly: true } );
  bindShortcut( ["command+up", "alt+up"], increaseBrightness, { modalOnly: true } );
  bindShortcut( ["command+down", "alt+down"], decreaseBrightness, { modalOnly: true } );
  bindShortcut( "shift+p", addProjects, { modalOnly: true, callback: focusProjects } );
  bindShortcut( "shift+f", addObservationFields, { modalOnly: true, callback: focusObservationFields } );
  _.forEach( annotationShortcuts, as => {
    bind( as.shortcut, ( ) => {
      if ( !isModalVisible( ) ) return false;
      dispatch( addAnnotationFromKeyboard( as.term, as.value ) );
      return false;
    } );
  } );
  bindShortcut( "?", toggleKeyboardShortcuts, { modalOnly: true } );
};

export default setupKeyboardShortcuts;
export { annotationShortcuts };

const SET_SECTION = "user/edit/SET_SECTION";

// Main sections of settings; may not be rendered when the page loads, so we
// need to handle this nav
const USER_SETTINGS_HASHES = [
  "#profile",
  "#account",
  "#notifications",
  "#relationships",
  "#content",
  "#applications"
];

// Actual anchor names that we can only navigate to when their corresponding
// section is rendered
const SUB_SECTION_HASHES = {
  "#favorite-projects": "#content"
};

export default function reducer( state = { section: 0 }, action ) {
  switch ( action.type ) {
    case SET_SECTION:
      return { ...state, section: action.section };
    default:
  }
  return state;
}

export function setSection( section ) {
  return {
    type: SET_SECTION,
    section
  };
}

export function setSelectedSectionFromHash( targetHash ) {
  return dispatch => {
    let index = USER_SETTINGS_HASHES.indexOf( targetHash );
    let sectionHash;

    // If this is a subsection hash, try to find the right section
    if ( index < 0 ) {
      sectionHash = SUB_SECTION_HASHES[targetHash];
      index = USER_SETTINGS_HASHES.indexOf( sectionHash );
    }

    if ( index >= 0 ) {
      dispatch( setSection( index ) );
      if ( sectionHash ) {
        // Try to scroll to the right element
        const el = document.getElementById( sectionHash.replace( "#", "" ) );
        el?.scrollIntoView( );
      }
    }
  };
}

export function setSelectedSectionFromMenu( menuItem ) {
  return dispatch => {
    window.location.hash = USER_SETTINGS_HASHES[menuItem];
    dispatch( setSection( menuItem ) );
  };
}

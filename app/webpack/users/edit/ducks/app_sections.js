const SET_SECTION = "user/edit/SET_SECTION";

const userSettingsHashes = ["#profile", "#account", "#notifications", "#relationships", "#content", "#applications"];

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
    const index = userSettingsHashes.indexOf( targetHash );

    if ( index !== -1 ) {
      dispatch( setSection( index ) );
    }
  };
}

export function setSelectedSectionFromMenu( menuItem ) {
  return dispatch => {
    window.location.hash = userSettingsHashes[menuItem];
    dispatch( setSection( menuItem ) );
  };
}

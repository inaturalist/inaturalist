const SET_ACTIVE_TAB = "obs-show/comment_id_panel/SET_ACTIVE_TAB";

export default function reducer( state = { activeTab: "comment" }, action ) {
  switch ( action.type ) {
    case SET_ACTIVE_TAB:
      return Object.assign( { }, state, { activeTab: action.activeTab } );
    default:
      // nothing to see here
  }
  return state;
}

export function setActiveTab( activeTab ) {
  return {
    type: SET_ACTIVE_TAB,
    activeTab
  };
}

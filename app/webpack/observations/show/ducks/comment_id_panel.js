const SET_ACTIVE_TAB = "obs-show/comment_id_panel/SET_ACTIVE_TAB";
const SET_NOMINATE_ON_SUBMIT = "obs-show/comment_id_panel/SET_NOMINATE_ON_SUBMIT";

export default function reducer( state = { activeTab: "comment" }, action ) {
  switch ( action.type ) {
    case SET_ACTIVE_TAB:
      return Object.assign( { }, state, { activeTab: action.activeTab } );
    case SET_NOMINATE_ON_SUBMIT:
      return Object.assign( { }, state, { nominate: action.nominate } );
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

export function setNominateOnSubmit( nominate ) {
  return {
    type: SET_NOMINATE_ON_SUBMIT,
    nominate
  };
}

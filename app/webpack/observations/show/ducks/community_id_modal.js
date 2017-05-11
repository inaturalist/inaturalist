const SET_COMMUNITY_ID_MODAL_STATE = "obs-show/community_id_modal/SET_COMMUNITY_ID_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_COMMUNITY_ID_MODAL_STATE:
      return Object.assign( { }, action.newState );
    default:
      // nothing to see here
  }
  return state;
}

export function setCommunityIDModalState( newState ) {
  return {
    type: SET_COMMUNITY_ID_MODAL_STATE,
    newState
  };
}

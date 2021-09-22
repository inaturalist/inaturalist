const SET_MODAL_STATE = "third_party_tracking_modal/SET_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_MODAL_STATE:
      return Object.assign( { }, action.newState );
    default:
      // nothing to see here
  }
  return state;
}

export function setModalState( newState ) {
  return {
    type: SET_MODAL_STATE,
    newState
  };
}

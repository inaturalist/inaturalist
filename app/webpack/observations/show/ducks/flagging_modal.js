const SET_FLAGGING_MODAL_STATE = "obs-show/flagging_modal/SET_FLAGGING_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  let newState;
  switch ( action.type ) {
    case SET_FLAGGING_MODAL_STATE:
      newState = Object.assign( { }, state, action.newState );
      if ( action.newState.show === true ) {
        newState.radioOption = "spam";
      }
      return newState;
    default:
  }
  return state;
}

export function setFlaggingModalState( newState ) {
  return {
    type: SET_FLAGGING_MODAL_STATE,
    newState
  };
}

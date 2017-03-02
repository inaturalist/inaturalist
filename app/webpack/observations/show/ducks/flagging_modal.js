const SET_STATE = "obs-show/flagging_modal/SET_STATE";

export default function reducer( state = { show: false }, action ) {
  let newState;
  switch ( action.type ) {
    case SET_STATE:
      newState = Object.assign( { }, state );
      newState[action.key] = action.value;
      if ( action.key === "show" ) {
        newState.radioOption = "spam";
      }
      return newState;
    default:
      // nothing to see here
  }
  return state;
}

export function setState( key, value ) {
  return {
    type: SET_STATE,
    key,
    value
  };
}

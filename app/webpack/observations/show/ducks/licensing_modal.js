const SET_LICENSING_MODAL_STATE = "obs-show/licensing_modal/SET_LICENSING_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_LICENSING_MODAL_STATE:
      return Object.assign( { }, action.newState );
    default:
      // nothing to see here
  }
  return state;
}

export function setLicensingModalState( newState ) {
  return {
    type: SET_LICENSING_MODAL_STATE,
    newState
  };
}

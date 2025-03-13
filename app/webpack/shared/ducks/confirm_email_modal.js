const SET_CONFIRM_EMAIL_MODAL_STATE = "shared/confirm_email_modal/SET_CONFIRM_EMAIL_MODAL_STATE";
const UPDATE_CONFIRM_EMAIL_MODAL_STATE = "shared/confirm_email_modal/UPDATE_CONFIRM_EMAIL_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_CONFIRM_EMAIL_MODAL_STATE:
      return { ...action.newState };
    case UPDATE_CONFIRM_EMAIL_MODAL_STATE:
      return { ...state, ...action.updatedState };
    default:
      // nothing to see here
  }
  return state;
}

export function setConfirmEmailModalState( newState ) {
  return {
    type: SET_CONFIRM_EMAIL_MODAL_STATE,
    newState
  };
}

export function updateConfirmEmailModalState( updatedState ) {
  return {
    type: UPDATE_CONFIRM_EMAIL_MODAL_STATE,
    updatedState
  };
}

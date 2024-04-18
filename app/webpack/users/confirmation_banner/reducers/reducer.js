import inatjs from "inaturalistjs";
import { setConfirmModalState } from "../../../observations/show/ducks/confirm_modal";

const SET_CONFIRMATION_EMAIL_SENT = "users-confirmation-banner/SET_CONFIRMATION_EMAIL_SENT";

export default function reducer( state = {
  confirmationEmailSent: false
}, action ) {
  switch ( action.type ) {
    case SET_CONFIRMATION_EMAIL_SENT:
      return { confirmationEmailSent: action.value };
    default:
  }
  return state;
}

export function setConfirmationEmailSent( ) {
  return {
    type: SET_CONFIRMATION_EMAIL_SENT,
    value: true
  };
}

export function confirmResendConfirmation( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "users_edit_send_confirmation_prompt_with_grace_html", {
        email: state.config.currentUser.email || ""
      } ),
      confirmText: I18n.t( "send_confirmation_email" ),
      onConfirm: async ( ) => {
        inatjs.users.resendConfirmation( { useAuth: true } ).then( ( ) => {
          dispatch( setConfirmationEmailSent( ) );
        // eslint-disable-next-line no-console
        } ).catch( console.log );
      }
    } ) );
  };
}

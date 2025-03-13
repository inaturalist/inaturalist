import inatjs from "inaturalistjs";
import { setConfirmEmailModalState } from "./confirm_email_modal";
import { makeLogRequest } from "../util";

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

export function confirmResendConfirmation( options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    makeLogRequest( "emailConfirmation", { extra: { action: "modalOpen" } } );
    dispatch( setConfirmEmailModalState( {
      show: true,
      hideCancel: ( options.cancellable === false ),
      preventClose: ( options.cancellable === false ),
      message: state.config.currentUser.email,
      type: "EmailConfirmation",
      confirmText: I18n.t( "send_confirmation_email" ),
      onConfirm: async ( ) => {
        makeLogRequest( "emailConfirmation", { extra: { action: "confirmationSent" } } );
        inatjs.users.resendConfirmation( { useAuth: true } ).then( ( ) => {
          if ( options.cancellable === false ) {
            return;
          }
          dispatch( setConfirmationEmailSent( ) );
        // eslint-disable-next-line no-console
        } ).catch( console.log );
      }
    } ) );
  };
}

export function performOrOpenConfirmationModal( method, options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state?.config?.currentUser ) {
      return;
    }
    if ( options.permitOwnerOf?.user?.id === state?.config?.currentUser?.id ) {
      method( );
      return;
    }
    if ( !state.config.currentUser?.privilegedWith( "interaction" ) ) {
      dispatch( confirmResendConfirmation( ) );
      return;
    }
    method( );
  };
}

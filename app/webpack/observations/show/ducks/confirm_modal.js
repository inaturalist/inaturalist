const SET_CONFIRM_MODAL_STATE = "obs-show/confirm_modal/SET_CONFIRM_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_CONFIRM_MODAL_STATE:
      return Object.assign( { }, action.newState );
    default:
      // nothing to see here
  }
  return state;
}

export function setConfirmModalState( newState ) {
  return {
    type: SET_CONFIRM_MODAL_STATE,
    newState
  };
}

export function handleAPIError( e, message ) {
  if ( !e || !message ) { return null; }
  return ( dispatch ) => {
    if ( e.response && e.response.status ) {
      e.response.text( ).then( text => {
        const body = JSON.parse( text );
        // these errors come from Rails and have their own usable error messages
        let railsErrors;
        if ( body && body.error && body.error.original && body.error.original.errors ) {
          railsErrors = body.error.original.errors;
        }
        dispatch( setConfirmModalState( {
          show: true,
          type: "error",
          hideCancel: true,
          confirmText: "OK",
          message,
          errors: railsErrors
        } ) );
      } );
    }
  };
}

import _ from "lodash";

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

export function handleAPIError( e, message, options = { } ) {
  if ( !e || !message ) { return null; }
  return dispatch => {
    if ( e.response && e.response.status ) {
      const handleErrorJson = body => {
        // these errors come from Rails and have their own usable error messages
        let railsErrors;
        if ( body && body.error && body.error.original && body.error.original.errors ) {
          // sometimes it's an array
          railsErrors = body.error.original.errors;
        } else if ( body && body.error && body.error.original && body.error.original.error ) {
          // sometimes it's just a string
          railsErrors = [body.error.original.error];
        } else if ( body && body.error && body.error.original ) {
          // sometimes we get rails errors keyed by attribute
          railsErrors = _.flatten( _.map( body.error.original, ( errors, attr ) => (
            _.map( errors, error => `${attr}: ${error}` )
          ) ) );
        } else if ( body && body.error ) {
          if ( typeof ( body.error ) === "string" ) {
            railsErrors = JSON.parse( body.error ).errors;
          } else if ( body.error.errors ) {
            railsErrors = body.error.errors;
          }
        }
        dispatch( setConfirmModalState( {
          show: true,
          type: "error",
          hideCancel: true,
          confirmText: "OK",
          message,
          errors: railsErrors,
          onConfirm: options.onConfirm
        } ) );
      };
      if ( e.response.bodyUsed ) {
        handleErrorJson( JSON.parse( e.message ) );
      } else {
        e.response.text( ).then( text => {
          handleErrorJson( JSON.parse( text ) );
        } ).catch( responseTextError => {
          console.warn( "[WARNING] : Failed to parse an error response: ", responseTextError );
        } );
      }
    }
  };
}

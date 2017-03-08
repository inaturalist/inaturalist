const SET_ERROR_MODAL_STATE = "obs-show/error_modal/SET_ERROR_MODAL_STATE";

export default function reducer( state = { show: false }, action ) {
  switch ( action.type ) {
    case SET_ERROR_MODAL_STATE:
    console.log(action.newState);
      return Object.assign( { }, action.newState );
    default:
      // nothing to see here
  }
  return state;
}

export function setErrorModalState( newState ) {
  return {
    type: SET_ERROR_MODAL_STATE,
    newState
  };
}

export function handleAPIError( e, message ) {
  return ( dispatch ) => {
    if ( e && e.response && e.response.status ) {
      e.response.text( ).then( text => {
        const body = JSON.parse( text );
        console.log(body);
        console.log(body.error.original.errors);
        if ( body && body.error && body.error.original && body.error.original.errors ) {
          dispatch( setErrorModalState( {
            show: true,
            message,
            errors: body.error.original.errors
          } ) );
        }
      } );
    }
  };
}

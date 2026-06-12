import { setAttributes, fetchObservation } from "./observation";

// Reads the Rails CSRF param name + token from the page <meta> tags, mirroring
// the pattern used by leaveTestGroup in ./users.
function csrfPair( ) {
  return {
    param: $( "meta[name=csrf-param]" ).attr( "content" ),
    token: $( "meta[name=csrf-token]" ).attr( "content" )
  };
}

function observerUserId( additionalObserver ) {
  if ( !additionalObserver ) { return null; }
  return additionalObserver.user ? additionalObserver.user.id : additionalObserver.id;
}

// POST /observations/:id/observers — the creator adds another user as an
// additional observer. Optimistically updates redux, then refetches the
// observation so the persisted list (incl. ES-hydrated user objects) wins.
export function addAdditionalObserver( user ) {
  return ( dispatch, getState ) => {
    const { observation, config } = getState( );
    if ( !observation || !config || !config.currentUser ) { return null; }
    if ( !user || !user.id ) { return null; }

    const existing = observation.additional_observers || [];
    dispatch( setAttributes( {
      additional_observers: existing.concat( [{ user, temporary: true }] )
    } ) );

    const { param, token } = csrfPair( );
    const body = new FormData( );
    body.append( param, token );
    body.append( "user_id", user.id );
    return fetch( `/observations/${observation.id}/observers`, {
      method: "post",
      credentials: "same-origin",
      body
    } ).then( response => {
      if ( response.status >= 200 && response.status < 300 ) {
        dispatch( fetchObservation( observation.uuid ) );
      } else {
        throw new Error( "Failed to add additional observer" );
      }
    } ).catch( ( ) => {
      // revert the optimistic update
      dispatch( setAttributes( { additional_observers: existing } ) );
    } );
  };
}

// DELETE /observations/:id/observers/:user_id (via _method override). Removes
// an additional observer the creator previously added.
export function removeAdditionalObserver( userId ) {
  return ( dispatch, getState ) => {
    const { observation, config } = getState( );
    if ( !observation || !config || !config.currentUser ) { return null; }

    const existing = observation.additional_observers || [];
    dispatch( setAttributes( {
      additional_observers: existing.filter( ao => observerUserId( ao ) !== userId )
    } ) );

    const { param, token } = csrfPair( );
    const body = new FormData( );
    body.append( param, token );
    body.append( "_method", "delete" );
    return fetch( `/observations/${observation.id}/observers/${userId}`, {
      method: "post",
      credentials: "same-origin",
      body
    } ).then( response => {
      if ( response.status >= 200 && response.status < 300 ) {
        dispatch( fetchObservation( observation.uuid ) );
      } else {
        throw new Error( "Failed to remove additional observer" );
      }
    } ).catch( ( ) => {
      dispatch( setAttributes( { additional_observers: existing } ) );
    } );
  };
}

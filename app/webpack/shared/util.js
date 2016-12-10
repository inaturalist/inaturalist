import isomorphicFetch from "isomorphic-fetch";

// Light wrapper around isomorphic fetch to ensure credentials are always passed through
const fetch = ( url, options ) =>
  isomorphicFetch( url, Object.assign( {}, options, { credentials: "same-origin" } ) );

function updateSession( params ) {
  const data = new FormData( );
  data.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
  for ( const key in params ) {
    data.append( key, params[key] );
  }
  fetch( "/users/update_session", {
    method: "PUT",
    body: data
  } );
}

export {
  fetch,
  updateSession
};

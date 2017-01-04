import isomorphicFetch from "isomorphic-fetch";
import _ from "lodash";

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

// Basically serialize an object so it can be used for deep object comparison,
// e.g. when deciding whether to udpate a react component
function objectToComparable( object = {} ) {
  return _.map( _.keys( object ).sort( ), k => {
    const v = object[k];
    // if ( _.isArrayLikeObject( v ) ) {
    if ( typeof( v ) === "object" ) {
      return `(${k}-${objectToComparable( v )})`;
    }
    return `(${k}-${v})`;
  } ).sort( ).join( "," );
}

export {
  fetch,
  updateSession,
  objectToComparable
};

import inatjs from "inaturalistjs";

const RECEIVE_IDENTIFIERS = "receive_identifiers";
const FETCH_IDENTIFIERS = "fetch_identifiers";

function receiveIdentifiers( response ) {
  return {
    type: RECEIVE_IDENTIFIERS,
    users: response.results
  };
}

function fetchIdentifiers( ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const apiParams = Object.assign( { }, s.searchParams, { reviewed: "any" } );
    return inatjs.observations.identifiers( apiParams )
      .then( response => dispatch( receiveIdentifiers( response ) ) );
  };
}

export {
  RECEIVE_IDENTIFIERS,
  FETCH_IDENTIFIERS,
  receiveIdentifiers,
  fetchIdentifiers
};

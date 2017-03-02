import inatjs from "inaturalistjs";

const SET_IDENTIFIERS = "obs-show/identifications/identifiers";

export default function reducer( state = { identifiers: [] }, action ) {
  switch ( action.type ) {
    case SET_IDENTIFIERS:
      return Object.assign( { }, state, { identifiers: action.identifiers } );
    default:
  }
  return state;
}

export function setIdentifiers( identifiers ) {
  return {
    type: SET_IDENTIFIERS,
    identifiers
  };
}

export function fetchIdentifiers( params ) {
  return ( dispatch ) => (
    inatjs.identifications.identifiers( params ).then( response => {
      dispatch( setIdentifiers( response.results ) );
    } )
  );
}

import inatjs from "inaturalistjs";

const SET_NETWORK_SITES = "user/edit/SET_NETWORK_SITES";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_NETWORK_SITES:
      return { ...state, sites: action.sites };
    default:
  }
  return state;
}

export function setNetworkSites( sites ) {
  return {
    type: SET_NETWORK_SITES,
    sites
  };
}


export function fetchNetworkSites( ) {
  return dispatch => inatjs.sites.fetch( ).then( ( { results } ) => {
    dispatch( setNetworkSites( results ) );
  } ).catch( e => console.log( `Failed to fetch network sites: ${e}` ) );
}

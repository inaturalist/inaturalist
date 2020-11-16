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
  const url = "https://api.inaturalist.org/v1/sites";

  return dispatch => fetch( url ).then( response => response.json( ) )
    .then( ( { results } ) => dispatch( setNetworkSites( results ) ) )
    .catch( e => console.log( `Failed to fetch network sites: ${e}` ) );
}

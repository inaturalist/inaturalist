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
  return ( dispatch, getState ) => {
    const { userSettings, sites } = getState( );
    let sitesToFetch;
    if ( sites && sites.sites ) {
      const siteIds = sites.sites.map( s => s.id );
      if ( siteIds.indexOf( userSettings.site_id ) < 0 ) {
        sitesToFetch = siteIds.concat( [userSettings.site_id] );
      }
    }
    const params = {
      fields: {
        id: true,
        name: true,
        icon_url: true
      }
    };
    inatjs.sites.fetch( sitesToFetch, params ).then( ( { results } ) => {
      dispatch( setNetworkSites( results ) );
      const { userSettings: userSettings2 } = getState( );
      // If we've loaded the current user's data and they seem to be affiliated
      // with a site that we don't know about (maybe a draft), try loading that
      // specific site and adding it
      const siteIds = results.map( s => s.id );
      if ( siteIds && userSettings2?.site_id && siteIds.indexOf( userSettings2.site_id ) < 0 ) {
        inatjs.sites.fetch( [userSettings2.site_id] )
          .then( ( { results: results2 } ) => {
            dispatch( setNetworkSites( results.concat( results2 ) ) );
          } )
          .catch( e => {
            console.log( "[DEBUG] User seems to be affiliated with a site that doesn't exist: ", e );
          } );
      }
    } ).catch( e => console.log( `Failed to fetch network sites: ${e}` ) );
  };
}

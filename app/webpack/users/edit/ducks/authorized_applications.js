import inatjs from "inaturalistjs";

const SET_AUTHENTICATED_APPS = "user/edit/SET_AUTHENTICATED_APPS";
const SET_PROVIDER_APPS = "user/edit/SET_PROVIDER_APPS";
const SET_APP_TO_DELETE = "user/edit/SET_APP_TO_DELETE";

export default function reducer( state = { id: null, apps: [], providerApps: [] }, action ) {
  switch ( action.type ) {
    case SET_AUTHENTICATED_APPS:
      return { ...state, apps: action.apps, id: null };
    case SET_PROVIDER_APPS:
      return { ...state, providerApps: action.providerApps, id: null };
    case SET_APP_TO_DELETE:
      return { ...state, id: action.id };
    default:
  }
  return state;
}

export function setApps( apps ) {
  return {
    type: SET_AUTHENTICATED_APPS,
    apps
  };
}

export function setProviderApps( providerApps ) {
  return {
    type: SET_PROVIDER_APPS,
    providerApps
  };
}

export function setAppToDelete( id ) {
  return {
    type: SET_APP_TO_DELETE,
    id
  };
}

export function fetchAuthorizedApps( ) {
  const params = { useAuth: true };
  return dispatch => inatjs.authorized_applications.search( params ).then( ( { results } ) => {
    dispatch( setApps( results ) );
  } ).catch( e => console.log( `Failed to fetch authorized applications: ${e}` ) );
}

export function deleteAuthorizedApp( ) {
  return ( dispatch, getState ) => {
    const { apps } = getState( );
    const { id } = apps;

    return inatjs.authorized_applications.delete( { id } ).then( ( ) => {
      dispatch( fetchAuthorizedApps( ) );
    } ).catch( e => console.log( `Failed to delete authorized application: ${e}` ) );
  };
}

export function fetchProviderApps( ) {
  const params = { useAuth: true };
  return dispatch => inatjs.provider_authorizations.search( params ).then( ( { results } ) => {
    dispatch( setProviderApps( results ) );
  } ).catch( e => console.log( `Failed to fetch provider authorizations: ${e}` ) );
}

export function deleteProviderApp( ) {
  return ( dispatch, getState ) => {
    const { apps } = getState( );
    const { id } = apps;

    console.log( id, "id in delete provider app" );

    return inatjs.provider_authorizations.delete( { id } ).then( ( ) => {
      dispatch( fetchProviderApps( ) );
    } ).catch( e => console.log( `Failed to delete provider authorization: ${e}` ) );
  };
}

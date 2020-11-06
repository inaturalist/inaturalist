import inatjs from "inaturalistjs";

const SET_AUTHENTICATED_APPS = "user/edit/SET_AUTHENTICATED_APPS";
const SET_APP_TO_DELETE = "user/edit/SET_APP_TO_DELETE";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_AUTHENTICATED_APPS:
      return { ...state, apps: action.apps };
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

export function setAppToDelete( id ) {
  return {
    type: SET_APP_TO_DELETE,
    id
  };
}

export function fetchAuthorizedApps( ) {
  const params = { useAuth: true };
  return dispatch => inatjs.authorized_applications.search( params ).then( ( { results } ) => {
    dispatch( setAppToDelete( null ) );
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

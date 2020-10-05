import inatjs from "inaturalistjs";

const SET_USER_DATA = "user/edit/SET_USER_DATA";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_USER_DATA:
      return { ...action.userData };
    default:
  }
  return state;
}

export function setUserData( userData ) {
  return {
    type: SET_USER_DATA,
    userData
  };
}

export function fetchUserProfile( ) {
  return ( dispatch, getState ) => {
    // const s = getState( );
    return inatjs.users.me( { useAuth: true } ).then( ( { results } ) => {
      dispatch( setUserData( results[0] ) );
      console.log( results, "results in inat users me" );
    } ).catch( e => console.log( `Failed to fetch user: ${e}` ) );
  };
}

export function updateUserProfile( ) {
  return ( dispatch, getState ) => {
    return inatjs.users.update( ).then( ( results ) => {
      console.log( results, "update users/edit" );
    } ).catch( e => console.log( `Failed to update user: ${e}` ) );
  };
}

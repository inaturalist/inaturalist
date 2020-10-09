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
  return dispatch => inatjs.users.me( { useAuth: true } ).then( ( { results } ) => {
    console.log( results[0], "profile-data" );
    dispatch( setUserData( results[0] ) );
  } ).catch( e => console.log( `Failed to fetch user: ${e}` ) );
}

export function saveUserSettings( ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const { id } = s.profile;

    const params = {
      id,
      user: s.profile
    };
    return inatjs.users.update( params, { useAuth: true } ).then( ( results ) => {
      console.log( results, "update users/edit" );
      dispatch( setUserData( results[0] ) );
    } ).catch( e => console.log( `Failed to update user: ${e}` ) );
  };
}

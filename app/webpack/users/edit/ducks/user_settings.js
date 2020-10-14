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

export function fetchUserSettings( ) {
  return dispatch => inatjs.users.me( { useAuth: true } ).then( ( { results } ) => {
    console.log( results[0], "profile-data" );
    dispatch( setUserData( results[0] ) );
  } ).catch( e => console.log( `Failed to fetch user: ${e}` ) );
}

export function saveUserSettings( ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    const { id } = profile;

    const params = {
      id,
      user: profile
    };

    params.user.updated_at = new Date( );

    return inatjs.users.update( params, { useAuth: true } ).then( ( ) => {
      // fetching user settings here to get the source of truth
      // currently users.me returns different results than
      // dispatching setUserData( results[0] ) from users.update response
      fetchUserSettings( );
    } ).catch( e => console.log( `Failed to update user: ${e}` ) );
  };
}

export function handleCheckboxChange( e ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile[e.target.name] = e.target.checked;
    dispatch( setUserData( profile ) );
  };
}

export function handleInputChange( e ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile[e.target.name] = e.target.value;
    dispatch( setUserData( profile ) );
  };
}

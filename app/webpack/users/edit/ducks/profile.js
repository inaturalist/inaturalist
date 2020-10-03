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
    const s = getState( );
    const currentUser = s.config.currentUser ? s.config.currentUser : null;
    const authenticityToken = $( "meta[name=csrf-token]" ).attr( "content" );

    return fetch( `/users/edit.json?authenticity_token=${authenticityToken}&id=${currentUser.id}` )
      .then( response => response.json( ) )
      .then( json => dispatch( setUserData( json ) ) )
      .catch( e => console.log( `Failed to fetch user: ${e}` ) );
  };
}

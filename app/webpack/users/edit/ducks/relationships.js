import inatjs from "inaturalistjs";

const SET_RELATIONSHIPS = "user/edit/SET_RELATIONSHIPS";
const SET_FILTERED_RELATIONSHIPS = "user/edit/SET_FILTERED_RELATIONSHIPS";
const SET_FILTERS = "user/edit/SET_FILTERS";
const SET_RELATIONSHIP_TO_DELETE = "user/edit/SET_RELATIONSHIP_TO_DELETE";

export default function reducer( state = { filters: { name: null, following: "all", trusted: "all" } }, action ) {
  switch ( action.type ) {
    case SET_RELATIONSHIPS:
      return { ...state, relationships: action.relationships };
    case SET_FILTERED_RELATIONSHIPS:
      return { ...state, filteredRelationships: action.filteredRelationships };
    case SET_FILTERS:
      return { ...state, filters: action.filters };
    case SET_RELATIONSHIP_TO_DELETE:
      return { ...state, id: action.id };
    default:
  }
  return state;
}

export function setRelationships( relationships ) {
  return {
    type: SET_RELATIONSHIPS,
    relationships
  };
}

export function setFilteredRelationships( filteredRelationships ) {
  return {
    type: SET_FILTERED_RELATIONSHIPS,
    filteredRelationships
  };
}

export function setFilters( filters ) {
  return {
    type: SET_FILTERS,
    filters
  };
}

// export function setRelationshipToDelete( id ) {
//   return {
//     type: SET_RELATIONSHIP_TO_DELETE,
//     id
//   };
// }

export function fetchRelationships( firstRender ) {
  const params = { useAuth: true };
  return dispatch => inatjs.relationships.search( params ).then( ( { results } ) => {
    if ( firstRender ) {
      dispatch( setFilteredRelationships( results ) );
    }
    dispatch( setRelationships( results ) );
  } ).catch( e => console.log( `Failed to fetch relationships: ${e}` ) );
}

export function handleCheckboxChange( e, friendId ) {
  return ( dispatch, getState ) => {
    const { relationships } = getState( );
    const friends = relationships.relationships;
    const targetFriend = friends.filter( user => user.friendUser.id === friendId );

    targetFriend[0][e.target.name] = e.target.checked;

    dispatch( setRelationships( friends ) );
  };
}

export function filterRelationships( ) {
  return ( dispatch, getState ) => {
    const { relationships } = getState( );
    const { filters } = relationships;

    const friends = relationships.relationships;

    let filteredFriends;

    // filterByName
    if ( filters.name !== null ) {
      // name and login can be null for new users
      filteredFriends = friends.filter(
        u => ( u.friendUser.name !== null && u.friendUser.name.includes( filters.name ) )
        || ( u.friendUser.login !== null && u.friendUser.login.includes( filters.name ) )
      );
    } else {
      // if no filters by name, show all
      filteredFriends = friends;
    }

    // filterByFollowing
    if ( filters.following === "yes" ) {
      filteredFriends = filteredFriends.filter( u => ( u.following === true ) );
    } else if ( filters.following === "no" ) {
      filteredFriends = filteredFriends.filter( u => ( u.following === false ) );
    }

    // filterByTrust
    if ( filters.trusted === "yes" ) {
      filteredFriends = filteredFriends.filter( u => ( u.trusted === true ) );
    } else if ( filters.trust === "no" ) {
      filteredFriends = filteredFriends.filter( u => ( u.trusted === false ) );
    }

    dispatch( setFilteredRelationships( filteredFriends ) );
  };
}

export function updateFilters( e ) {
  const { value, name } = e.target;

  return ( dispatch, getState ) => {
    const { relationships } = getState( );
    const { filters } = relationships;

    filters[name] = value;
    dispatch( setFilters( filters ) );
    dispatch( filterRelationships( ) );
  };
}

export function sortRelationships( e ) {
  const { value } = e.target;

  return ( dispatch, getState ) => {
    const { relationships } = getState( );
    const { filteredRelationships } = relationships;

    let sorted;

    if ( value === "recently_added" ) {
      sorted = filteredRelationships.sort(
        ( a, b ) => new Date( b.created_at ) - new Date( a.created_at )
      );
    }

    if ( value === "earliest_added" ) {
      sorted = filteredRelationships.sort(
        ( a, b ) => new Date( a.created_at ) - new Date( b.created_at )
      );
    }

    if ( value === "a_to_z" ) {
      sorted = filteredRelationships.sort(
        ( a, b ) => a.friendUser.login.localeCompare( b.friendUser.login )
      );
    }

    if ( value === "z_to_a" ) {
      sorted = filteredRelationships.sort(
        ( a, b ) => b.friendUser.login.localeCompare( a.friendUser.login )
      );
    }

    dispatch( setFilteredRelationships( sorted ) );
  };
}

// export function deleteRelationship( ) {
//   return ( dispatch, getState ) => {
//     const { relationships } = getState( );
//     const { id } = relationships;

//     return inatjs.relationships.delete( { id } ).then( results => {
//       console.log( results, "results" );
//       dispatch( fetchRelationships( ) );
//     } ).catch( e => console.log( `Failed to delete relationships: ${e}` ) );
//   };
// }

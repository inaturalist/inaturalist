import inatjs from "inaturalistjs";

import { fetchUserSettings } from "./user_settings";

const SET_RELATIONSHIPS = "user/edit/SET_RELATIONSHIPS";
const SET_FILTERED_RELATIONSHIPS = "user/edit/SET_FILTERED_RELATIONSHIPS";
const SET_FILTERS = "user/edit/SET_FILTERS";
const SET_RELATIONSHIP_TO_DELETE = "user/edit/SET_RELATIONSHIP_TO_DELETE";
const SET_USER_AUTOCOMPLETE = "user/edit/SET_USER_AUTOCOMPLETE";
const SET_BLOCKED_USERS = "user/edit/SET_BLOCKED_USERS";
const SET_MUTED_USERS = "user/edit/SET_MUTED_USERS";
const SET_PAGE = "user/edit/SET_PAGE";

export default function reducer( state = {
  filters: { name: null, following: "all", trusted: "all" },
  blockedUsers: [],
  mutedUsers: [],
  page: 1
}, action ) {
  console.log( action.type, "action type" );
  switch ( action.type ) {
    case SET_RELATIONSHIPS:
      return { ...state, relationships: action.relationships };
    case SET_FILTERED_RELATIONSHIPS:
      return { ...state, filteredRelationships: action.filteredRelationships };
    case SET_FILTERS:
      return { ...state, filters: action.filters };
    case SET_RELATIONSHIP_TO_DELETE:
      return { ...state, id: action.id };
    case SET_USER_AUTOCOMPLETE:
      return { ...state, users: action.users };
    case SET_BLOCKED_USERS:
      return { ...state, blockedUsers: action.blockedUsers };
    case SET_MUTED_USERS:
      return { ...state, mutedUsers: action.mutedUsers };
    case SET_PAGE:
      return { ...state, page: action.page };
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

export function setRelationshipToDelete( id ) {
  return {
    type: SET_RELATIONSHIP_TO_DELETE,
    id
  };
}

export function setUserAutocomplete( users ) {
  return {
    type: SET_USER_AUTOCOMPLETE,
    users
  };
}

export function setBlockedUsers( blockedUsers ) {
  return {
    type: SET_BLOCKED_USERS,
    blockedUsers
  };
}

export function setMutedUsers( mutedUsers ) {
  return {
    type: SET_MUTED_USERS,
    mutedUsers
  };
}

export function setPage( page ) {
  return {
    type: SET_PAGE,
    page
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

export function fetchMutedUsers( ids ) {
  return ( dispatch, getState ) => {
    let { mutedUsers } = getState( ).relationships;

    mutedUsers = [];

    ids.forEach( id => inatjs.users.fetch( id ).then( ( { results } ) => {
      mutedUsers.push( results[0] );
      dispatch( setMutedUsers( mutedUsers ) );
    } ).catch( e => console.log( `Failed to fetch muted users: ${e}` ) ) );
  };
}

export function fetchBlockedUsers( ids ) {
  return ( dispatch, getState ) => {
    let { blockedUsers } = getState( ).relationships;

    blockedUsers = [];

    ids.forEach( id => inatjs.users.fetch( id ).then( ( { results } ) => {
      blockedUsers.push( results[0] );
      dispatch( setBlockedUsers( blockedUsers ) );
    } ).catch( e => console.log( `Failed to fetch blocked users: ${e}` ) ) );
  };
}


export function fetchRelationships( firstRender ) {
  const params = { useAuth: true };
  console.log( firstRender, "first render" );
  return dispatch => inatjs.relationships.search( params ).then( ( { results } ) => {
    if ( firstRender ) {
      dispatch( setFilteredRelationships( results ) );
    }
    dispatch( setRelationships( results ) );
    dispatch( filterRelationships( ) );
    dispatch( fetchMutedUsers( ) );
  } ).catch( e => console.log( `Failed to fetch relationships: ${e}` ) );
}

export function updateRelationship( id, friendship ) {
  const params = { id, friendship };
  return dispatch => inatjs.relationships.update( params ).then( ( ) => {
    dispatch( fetchRelationships( ) );
  } ).catch( e => console.log( `Failed to update relationship: ${e}` ) );
}

export function handleCheckboxChange( e, friendId ) {
  const { name, checked } = e.target;

  return ( dispatch, getState ) => {
    const { relationships } = getState( );
    const friends = relationships.relationships;
    const targetFriend = friends.filter( user => user.friendUser.id === friendId );

    targetFriend[0][name] = checked;

    dispatch( updateRelationship( friendId, { [name]: checked } ) );
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

export function deleteRelationship( ) {
  return ( dispatch, getState ) => {
    const { relationships } = getState( );
    const { id } = relationships;

    return inatjs.relationships.delete( { id } ).then( ( ) => {
      dispatch( fetchRelationships( true ) );
    } ).catch( e => console.log( `Failed to delete relationships: ${e}` ) );
  };
}

export function muteUser( id ) {
  const params = { useAuth: true, id };
  return dispatch => inatjs.users.mute( params ).then( ( ) => {
    dispatch( fetchUserSettings( ) );
  } ).catch( e => console.log( `Failed to mute user: ${e}` ) );
}

export function unmuteUser( id ) {
  const params = { useAuth: true, id };
  return dispatch => inatjs.users.unmute( params ).then( ( ) => {
    dispatch( fetchUserSettings( ) );
  } ).catch( e => console.log( `Failed to unmute user: ${e}` ) );
}

export function blockUser( id ) {
  const params = { useAuth: true, id };
  return dispatch => inatjs.users.block( params ).then( ( ) => {
    dispatch( fetchUserSettings( ) );
  } ).catch( e => {
    console.log( `Failed to block user: ${e}` );
    dispatch( fetchUserSettings( ) );
  } );
}

export function unblockUser( id ) {
  const params = { useAuth: true, id };
  return dispatch => inatjs.users.unblock( params ).then( ( ) => {
    dispatch( fetchUserSettings( ) );
  } ).catch( e => console.log( `Failed to unblock user: ${e}` ) );
}

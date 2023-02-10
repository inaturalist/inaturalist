import _ from "lodash";
import inatjs from "inaturalistjs";

import { fetchUserSettings } from "./user_settings";

const SET_RELATIONSHIPS = "user/edit/SET_RELATIONSHIPS";
const SET_RELATIONSHIP_TO_DELETE = "user/edit/SET_RELATIONSHIP_TO_DELETE";
const SET_USER_AUTOCOMPLETE = "user/edit/SET_USER_AUTOCOMPLETE";
const SET_BLOCKED_USERS = "user/edit/SET_BLOCKED_USERS";
const SET_MUTED_USERS = "user/edit/SET_MUTED_USERS";
const SET_FILTERS = "user/edit/SET_FILTERS";

export default function reducer( state = {
  blockedUsers: [],
  mutedUsers: [],
  filters: {
    following: "any",
    trusted: "any",
    order_by: "users.login",
    order: "desc"
  },
  relationships: []
}, action ) {
  switch ( action.type ) {
    case SET_RELATIONSHIPS:
      return {
        ...state,
        relationships: action.relationships,
        page: action.page,
        totalRelationships: action.totalRelationships
      };
    case SET_RELATIONSHIP_TO_DELETE:
      return { ...state, id: action.id };
    case SET_USER_AUTOCOMPLETE:
      return { ...state, users: action.users };
    case SET_BLOCKED_USERS:
      return { ...state, blockedUsers: action.blockedUsers };
    case SET_MUTED_USERS:
      return { ...state, mutedUsers: action.mutedUsers };
    case SET_FILTERS:
      return { ...state, filters: action.filters };
    default:
  }
  return state;
}

export function setRelationships( relationships, page, totalRelationships ) {
  return {
    type: SET_RELATIONSHIPS,
    relationships,
    page,
    totalRelationships
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

export function setFilters( filters ) {
  return {
    type: SET_FILTERS,
    filters
  };
}

export function fetchMutedUsers( ) {
  return ( dispatch, getState ) => {
    const { relationships, profile, config } = getState( );
    const { mutedUsers } = relationships;
    const currentMutedUsers = profile.muted_user_ids || [];

    const params = { };
    if ( config.testingApiV2 ) {
      params.fields = {
        id: true,
        login: true,
        name: true,
        icon_url: true
      };
    }

    if ( mutedUsers.length === 0 ) {
      currentMutedUsers.forEach( id => inatjs.users.fetch( id, params ).then( ( { results } ) => {
        mutedUsers.push( results[0] );
        dispatch( setMutedUsers( mutedUsers ) );
      } ).catch( e => console.log( `Failed to fetch muted users: ${e}` ) ) );
    } else if ( mutedUsers.length < currentMutedUsers.length ) {
      // find the missing index and fetch that user
      const ids = mutedUsers.map( user => user.id );
      const idToFetch = currentMutedUsers.filter( u => !ids.includes( u ) );

      inatjs.users.fetch( idToFetch, params ).then( ( { results } ) => {
        mutedUsers.push( results[0] );
        dispatch( setMutedUsers( mutedUsers ) );
      } ).catch( e => console.log( `Failed to fetch muted users: ${e}` ) );
    } else if ( mutedUsers.length > currentMutedUsers.length ) {
      // remove that user from the current list
      const ids = mutedUsers.map( user => user.id );
      const idToRemove = ids.filter( u => !currentMutedUsers.includes( u ) )[0];
      const index = mutedUsers.findIndex( i => i.id === idToRemove );

      mutedUsers.splice( index, 1 );
      dispatch( setMutedUsers( mutedUsers ) );
    }
  };
}

export function fetchBlockedUsers( ) {
  return ( dispatch, getState ) => {
    const { relationships, profile, config } = getState( );
    const { blockedUsers } = relationships;
    const currentBlockedUsers = profile.blocked_user_ids || [];

    const params = { };
    if ( config.testingApiV2 ) {
      params.fields = {
        id: true,
        login: true,
        name: true,
        icon_url: true
      };
    }

    if ( blockedUsers.length === 0 ) {
      currentBlockedUsers.forEach( id => inatjs.users.fetch( id, params ).then( ( { results } ) => {
        blockedUsers.push( results[0] );
        dispatch( setBlockedUsers( blockedUsers ) );
      } ).catch( e => console.log( `Failed to fetch blocked users: ${e}` ) ) );
    } else if ( blockedUsers.length < currentBlockedUsers.length ) {
      // find the missing index and fetch that user
      const ids = blockedUsers.map( user => user.id );
      const idToFetch = currentBlockedUsers.filter( u => !ids.includes( u ) );

      inatjs.users.fetch( idToFetch, params ).then( ( { results } ) => {
        blockedUsers.push( results[0] );
        dispatch( setBlockedUsers( blockedUsers ) );
      } ).catch( e => console.log( `Failed to fetch blocked users: ${e}` ) );
    } else if ( blockedUsers.length > currentBlockedUsers.length ) {
      // remove that user from the current list
      const ids = blockedUsers.map( user => user.id );
      const idToRemove = ids.filter( u => !currentBlockedUsers.includes( u ) )[0];
      const index = blockedUsers.findIndex( i => i.id === idToRemove );

      blockedUsers.splice( index, 1 );
      dispatch( setBlockedUsers( blockedUsers ) );
    }
  };
}

export function updateBlockedAndMutedUsers( ) {
  return dispatch => {
    dispatch( fetchBlockedUsers( ) );
    dispatch( fetchMutedUsers( ) );
  };
}

export function fetchRelationships( firstRender, currentPage = 1 ) {
  const params = { page: currentPage, per_page: 10 };

  return ( dispatch, getState ) => {
    const state = getState( );
    const { filters } = state.relationships;

    const paramsWithFilters = {
      ...params,
      ...filters
    };

    if ( state.config.testingApiV2 ) {
      paramsWithFilters.fields = {
        id: true,
        trust: true,
        following: true,
        created_at: true,
        friend_user: {
          id: true,
          login: true,
          icon_url: true
        }
      };
    }
    inatjs.relationships.search( _.omitBy( paramsWithFilters, _.isNil ) ).then( response => {
      const { results, page } = response;

      if ( firstRender ) {
        dispatch( updateBlockedAndMutedUsers( ) );
      }

      dispatch( setRelationships( results, page, response.total_results ) );
    } ).catch( e => console.log( `Failed to fetch relationships: ${e}` ) );
  };
}

export function setRelationshipFilters( newFilters ) {
  return ( dispatch, getState ) => {
    const { filters } = getState( ).relationships;

    const updatedFilters = {
      ...filters,
      ...newFilters
    };

    dispatch( setFilters( updatedFilters ) );
    dispatch( fetchRelationships( ) );
  };
}

export function updateRelationship( id, relationship ) {
  // user id, not friendUser id
  const params = { id, relationship };
  return dispatch => inatjs.relationships.update( params ).then( ( ) => {
    dispatch( fetchRelationships( ) );
  } ).catch( e => console.log( `Failed to update relationship: ${e}` ) );
}

export function handleCheckboxChange( e, id ) {
  const { name, checked } = e.target;

  return ( dispatch, getState ) => {
    const { relationships } = getState( );
    const friends = relationships.relationships;
    const targetFriend = friends.filter( user => user.id === id );

    targetFriend[0][name] = checked;

    dispatch( updateRelationship( id, { [name]: checked } ) );
  };
}

export function deleteRelationship( ) {
  return ( dispatch, getState ) => {
    const { relationships } = getState( );
    const { id } = relationships;

    // noting that the correct id to be deleted is the user id, not the friendUser id
    return inatjs.relationships.delete( { id } ).then( ( ) => {
      dispatch( fetchRelationships( ) );
    } ).catch( e => console.log( `Failed to delete relationships: ${e}` ) );
  };
}

export function muteUser( id ) {
  const params = { id };
  return dispatch => inatjs.users.mute( params ).then( ( ) => {
    dispatch( fetchUserSettings( false, true ) );
  } ).catch( e => console.log( `Failed to mute user: ${e}` ) );
}

export function unmuteUser( id ) {
  const params = { id };
  return dispatch => inatjs.users.unmute( params ).then( ( ) => {
    dispatch( fetchUserSettings( false, true ) );
  } ).catch( e => console.log( `Failed to unmute user: ${e}` ) );
}

export function blockUser( id ) {
  const params = { id };
  return dispatch => inatjs.users.block( params ).then( ( ) => {
    dispatch( fetchUserSettings( false, true ) );
  } ).catch( e => {
    e.response.json( ).then( json => {
      const baseErrors = _.get( json, "error.original.errors.base", [] );
      if ( baseErrors.length > 0 ) {
        alert( baseErrors.join( "; " ) );
      }
    } );
    console.log( `Failed to block user: ${e}` );
  } );
}

export function unblockUser( id ) {
  const params = { id };
  return dispatch => inatjs.users.unblock( params ).then( ( ) => {
    dispatch( fetchUserSettings( false, true ) );
  } ).catch( e => console.log( `Failed to unblock user: ${e}` ) );
}

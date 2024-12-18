import _ from "lodash";
import { fetch } from "../util";
import CurrentUser from "../models/current_user";
import Config from "../models/config";

// ACTIONS
const CONFIG = "CONFIG";
const UPDATE_CONFIG = "UPDATE_CONFIG";
const TOGGLE_CONFIG = "TOGGLE_CONFIG";
const UPDATE_CURRENT_USER = "config/update_current_user";

// REDUCER
export default function reducer( state = new Config( { } ), action ) {
  let updatedState;
  switch ( action.type ) {
    case CONFIG:
      updatedState = { ...action.config };
      // eslint-disable-next-line no-restricted-syntax
      if ( action.config.currentUser && action.config.currentUser.constructor !== CurrentUser ) {
        updatedState.currentUser = new CurrentUser( action.config.currentUser );
      }
      return Object.assign( state, updatedState );
    case UPDATE_CONFIG: {
      updatedState = { ...action.config };
      if ( action.config.currentUser && action.config.currentUser.constructor !== CurrentUser ) {
        updatedState.currentUser = new CurrentUser( action.config.currentUser );
      }
      return {
        ...state,
        ...updatedState
      };
    }
    case TOGGLE_CONFIG:
      return Object.assign( state, { [action.key]: !state[action.key] } );
    case UPDATE_CURRENT_USER: {
      if ( !state.currentUser ) return state;
      if ( !state.currentUser.id ) return state;
      const prefUpdates = _.pickBy(
        action.updates,
        ( v, k ) => ( k.match( /prefers_/ ) || k.match( /preferred_/ ) )
      );
      if ( _.keys( prefUpdates ).length > 0 ) {
        const body = new FormData( );
        body.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
        _.forEach( action.updates, ( v, k ) => {
          body.append( `user[${k}]`, `${v}` );
        } );
        fetch( `/users/${state.currentUser.id}.json`, {
          method: "PUT",
          body
        } );
      }
      return Object.assign(
        state,
        { currentUser: Object.assign( state.currentUser, action.updates ) }
      );
    }
    default:
      return state;
  }
}

// ACTION CREATORS
export function setConfig( config ) {
  return {
    type: CONFIG,
    config
  };
}

export function updateConfig( config ) {
  return {
    type: UPDATE_CONFIG,
    config
  };
}

export function toggleConfig( key ) {
  return {
    type: TOGGLE_CONFIG,
    key
  };
}

export function updateCurrentUser( updates ) {
  return {
    type: UPDATE_CURRENT_USER,
    updates
  };
}

export function setCurrentUser( currentUser ) {
  return dispatch => {
    dispatch( setConfig( {
      currentUser: new CurrentUser( currentUser )
    } ) );
  };
}

export function trustUser( user ) {
  const body = new FormData( );
  body.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
  fetch( `/users/${user.id}/trust`, { method: "PUT", body } );
  return ( dispatch, getState ) => {
    const { currentUser } = getState( ).config;
    const currentTrustedUserIds = currentUser.trusted_user_ids || [];
    dispatch( updateCurrentUser( {
      trusted_user_ids: _.uniq( currentTrustedUserIds.concat( [user.id] ) )
    } ) );
  };
}

export function untrustUser( user ) {
  const body = new FormData( );
  body.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
  fetch( `/users/${user.id}/untrust`, { method: "PUT", body } );
  return ( dispatch, getState ) => {
    const { currentUser } = getState( ).config;
    const currentTrustedUserIds = currentUser.trusted_user_ids || [];
    dispatch( updateCurrentUser( {
      trusted_user_ids: _.without( currentTrustedUserIds, user.id )
    } ) );
  };
}

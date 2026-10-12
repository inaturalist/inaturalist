import _ from "lodash";
import inatjs from "inaturalistjs";
import { fetch } from "../util";
import CurrentUser from "../models/current_user";
import Config from "../models/config";

// ACTIONS
const CONFIG = "CONFIG";
const TOGGLE_CONFIG = "TOGGLE_CONFIG";
const UPDATE_CURRENT_USER = "config/update_current_user";

// REDUCER
export default function reducer( state = new Config( { } ), action ) {
  let updatedState;
  switch ( action.type ) {
    case CONFIG:
      updatedState = { ...action.config };
      if ( action.config.currentUser && action.config.currentUser.constructor !== CurrentUser ) {
        updatedState.currentUser = new CurrentUser( action.config.currentUser );
      }
      return new Config( Object.assign( state, updatedState ) );
    case TOGGLE_CONFIG:
      return new Config( Object.assign( state, { [action.key]: !state[action.key] } ) );
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
      return new Config(
        Object.assign(
          state,
          { currentUser: Object.assign( state.currentUser, action.updates ) }
        )
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

export function toggleConfig( key ) {
  return {
    type: TOGGLE_CONFIG,
    key
  };
}

export function enableApiV2( ) {
  return dispatch => {
    // check for an API v2 meta tag
    const apiV2UrlElement = document.querySelector( "meta[name=\"config:inaturalist_api_url_v2\"]" );
    let apiV2Url = apiV2UrlElement && apiV2UrlElement.getAttribute( "content" );
    if ( !apiV2Url ) {
      // check for an API v1 meta tag
      const apiUrlElement = document.querySelector( "meta[name=\"config:inaturalist_api_url\"]" );
      apiV2Url = apiUrlElement && apiUrlElement.getAttribute( "content" ).replace( "/v1", "/v2" );
    }
    if ( !apiV2Url ) {
      return;
    }

    // update config to indicate API v2 has been enabled
    dispatch( setConfig( {
      testingApiV2: true
    } ) );
    // update the inatjs config for this session
    inatjs.setConfig( {
      apiURL: apiV2Url,
      writeApiURL: apiV2Url
    } );
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
    const user = new CurrentUser( currentUser );
    // Lazy: the first featureFlagEnabled call fires the request; see CurrentUser.
    // eslint-disable-next-line no-use-before-define
    user.loadFeatureFlags = ( ) => dispatch( fetchFeatureFlags( ) );
    dispatch( setConfig( { currentUser: user } ) );
  };
}

// Loads the per-actor flag map from API v2 into currentUser. Fired by the first
// CurrentUser#featureFlagEnabled call rather than at boot, so only pages that read a flag pay
// for the request. Anonymous visitors get no flags because there is no currentUser to hold them.
export function fetchFeatureFlags( ) {
  return ( dispatch, getState ) => {
    const { currentUser } = getState( ).config;
    if ( !currentUser || !currentUser.id ) return Promise.resolve( );
    // Endpoint arrives with inaturalistjs WEB-1168; until node_modules picks it up, stay off.
    if ( !inatjs.feature_flags ) return Promise.resolve( );
    const apiV2Url = document
      .querySelector( "meta[name='config:inaturalist_api_url_v2']" )
      ?.getAttribute( "content" );
    if ( !apiV2Url ) return Promise.resolve( );
    // feature_flags exists only on API v2. The client stays on v2 afterwards: inatjs does not
    // expose its current URL, and every page that dispatches this must already handle v2.
    inatjs.setConfig( { apiURL: apiV2Url, writeApiURL: apiV2Url } );
    return inatjs.feature_flags.get( )
      .then( response => dispatch( updateCurrentUser( { featureFlags: response.flags || { } } ) ) )
      // Fail closed like Rails and the Node proxy: an unreachable API reads as everything off
      .catch( ( ) => dispatch( updateCurrentUser( { featureFlags: { } } ) ) );
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
